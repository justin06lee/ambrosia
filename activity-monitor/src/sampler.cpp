#include "sampler.h"

#include <KService>

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QProcess>

#include <functional>

#include <arpa/inet.h>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <linux/inet_diag.h>
#include <linux/netlink.h>
#include <linux/rtnetlink.h>
#include <linux/sock_diag.h>
#include <linux/tcp.h>
#include <netinet/in.h>
#include <pwd.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>

namespace
{
// The kernel marks its own threads with this in a task's flags.
constexpr quint64 KernelThread = 0x00200000;

// A whole file of /proc, which never says how long it is beforehand.
QByteArray slurp(const char *path)
{
    const int fd = ::open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return {};
    QByteArray all;
    char buffer[4096];
    for (;;) {
        const ssize_t n = ::read(fd, buffer, sizeof buffer);
        if (n <= 0)
            break;
        all.append(buffer, n);
    }
    ::close(fd);
    return all;
}

// The number after `key` in a file of "key: value" lines, or -1.
qint64 after(const QByteArray &text, const char *key)
{
    const int at = text.indexOf(key);
    if (at < 0)
        return -1;
    const char *p = text.constData() + at + qstrlen(key);
    while (*p == ' ' || *p == '\t')
        ++p;
    return strtoll(p, nullptr, 10);
}

// How often the process's threads have gone to sleep of their own accord
// (and so been woken again): the nearest the kernel has to a Mac's idle
// wake-ups. Every thread says its own.
qint64 voluntarySwitches(int pid, int threads)
{
    char path[96];
    if (threads <= 1) {
        snprintf(path, sizeof path, "/proc/%d/status", pid);
        return after(slurp(path), "\nvoluntary_ctxt_switches:");
    }
    snprintf(path, sizeof path, "/proc/%d/task", pid);
    DIR *tasks = opendir(path);
    if (!tasks)
        return -1;
    qint64 sum = 0;
    bool any = false;
    while (const dirent *task = readdir(tasks)) {
        if (task->d_name[0] < '0' || task->d_name[0] > '9')
            continue;
        snprintf(path, sizeof path, "/proc/%d/task/%s/status", pid, task->d_name);
        const qint64 one = after(slurp(path), "\nvoluntary_ctxt_switches:");
        if (one >= 0) {
            sum += one;
            any = true;
        }
    }
    closedir(tasks);
    return any ? sum : -1;
}

// Every TCP connection the kernel has, with what it has carried: asked of
// the kernel's socket diagnostics, which answer anyone. `each` gets the
// socket's inode (how /proc/PID/fd names it), its counters and its two ends.
void connections(int family, const std::function<void(quint64, const tcp_info &, const QString &)> &each)
{
    const int fd = ::socket(AF_NETLINK, SOCK_DGRAM | SOCK_CLOEXEC, NETLINK_SOCK_DIAG);
    if (fd < 0)
        return;
    timeval patience{0, 200000};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &patience, sizeof patience);
    struct {
        nlmsghdr header;
        inet_diag_req_v2 ask;
    } request{};
    request.header.nlmsg_len = sizeof request;
    request.header.nlmsg_type = SOCK_DIAG_BY_FAMILY;
    request.header.nlmsg_flags = NLM_F_REQUEST | NLM_F_DUMP;
    request.ask.sdiag_family = family;
    request.ask.sdiag_protocol = IPPROTO_TCP;
    request.ask.idiag_ext = 1 << (INET_DIAG_INFO - 1);
    request.ask.idiag_states = ~0u;
    if (::send(fd, &request, sizeof request, 0) < 0) {
        ::close(fd);
        return;
    }
    QByteArray buffer(65536, Qt::Uninitialized);
    bool done = false;
    while (!done) {
        const ssize_t got = ::recv(fd, buffer.data(), buffer.size(), 0);
        if (got <= 0)
            break;
        int left = int(got);
        for (auto *header = reinterpret_cast<nlmsghdr *>(buffer.data()); NLMSG_OK(header, left); header = NLMSG_NEXT(header, left)) {
            if (header->nlmsg_type == NLMSG_DONE || header->nlmsg_type == NLMSG_ERROR) {
                done = true;
                break;
            }
            const auto *message = static_cast<const inet_diag_msg *>(NLMSG_DATA(header));
            int room = int(header->nlmsg_len) - int(NLMSG_LENGTH(sizeof *message));
            for (auto *attribute = reinterpret_cast<const rtattr *>(message + 1); RTA_OK(attribute, room); attribute = RTA_NEXT(attribute, room)) {
                if (attribute->rta_type != INET_DIAG_INFO)
                    continue;
                tcp_info info{};
                memcpy(&info, RTA_DATA(attribute), qMin<size_t>(sizeof info, RTA_PAYLOAD(attribute)));
                char from[INET6_ADDRSTRLEN] = "", to[INET6_ADDRSTRLEN] = "";
                inet_ntop(message->idiag_family, message->id.idiag_src, from, sizeof from);
                inet_ntop(message->idiag_family, message->id.idiag_dst, to, sizeof to);
                const int toPort = ntohs(message->id.idiag_dport);
                QString ends = QStringLiteral("%1:%2").arg(QLatin1String(from)).arg(ntohs(message->id.idiag_sport));
                if (toPort != 0)
                    ends += QStringLiteral("->%1:%2").arg(QLatin1String(to)).arg(toPort);
                each(message->idiag_inode, info, ends);
            }
        }
    }
    ::close(fd);
}

// The inode of the socket a /proc/PID/fd link names ("socket:[1234]"), or 0.
quint64 socketInode(const char *link)
{
    if (strncmp(link, "socket:[", 8) != 0)
        return 0;
    return strtoull(link + 8, nullptr, 10);
}
}

Sampler::Sampler(QObject *parent)
    : QObject(parent)
{
    m_tick = sysconf(_SC_CLK_TCK) > 0 ? sysconf(_SC_CLK_TCK) : 100;
    m_page = sysconf(_SC_PAGESIZE) > 0 ? sysconf(_SC_PAGESIZE) : 4096;
    readApps();
    m_timer.setInterval(5000);
    connect(&m_timer, &QTimer::timeout, this, &Sampler::sample);
    connect(this, &Sampler::wantsChanged, this, [this] {
        // A tab that has just come into view shows its own columns at once
        // (their rates a reading later).
        QTimer::singleShot(250, this, &Sampler::sample);
    });
    sample();
    // A second reading soon, so the rates aren't empty for a whole interval.
    QTimer::singleShot(1000, this, &Sampler::sample);
    m_timer.start();
}

void Sampler::setInterval(int milliseconds)
{
    milliseconds = qBound(500, milliseconds, 60000);
    if (milliseconds == m_timer.interval())
        return;
    m_timer.setInterval(milliseconds);
    Q_EMIT intervalChanged();
}

int Sampler::me() const
{
    return int(geteuid());
}

QString Sampler::userName(uint uid)
{
    const auto known = m_users.constFind(uid);
    if (known != m_users.constEnd())
        return *known;
    const passwd *entry = getpwuid(uid);
    const QString name = entry ? QString::fromLocal8Bit(entry->pw_name) : QString::number(uid);
    m_users.insert(uid, name);
    return name;
}

// The apps the launcher knows, by the file each runs: a process running
// that file is the app, and takes its name and icon. A file several
// entries run (a settings module's host) is nobody's unless one entry is
// named for it.
void Sampler::readApps()
{
    QHash<QString, KService::List> byFile;
    const KService::List all = KService::allServices();
    for (const KService::Ptr &service : all) {
        if (!service->isApplication() || service->noDisplay())
            continue;
        QString file;
        const QStringList words = service->exec().split(QLatin1Char(' '), Qt::SkipEmptyParts);
        for (const QString &word : words) {
            if (word == QLatin1String("env") || word.contains(QLatin1Char('=')))
                continue;
            file = word.section(QLatin1Char('/'), -1);
            break;
        }
        static const QStringList runners{QStringLiteral("flatpak"), QStringLiteral("sh"), QStringLiteral("bash"), QStringLiteral("python"), QStringLiteral("python3"), QStringLiteral("kcmshell6"), QStringLiteral("xdg-open")};
        if (file.isEmpty() || runners.contains(file))
            continue;
        byFile[file].append(service);
    }
    for (auto it = byFile.constBegin(); it != byFile.constEnd(); ++it) {
        KService::Ptr chosen;
        if (it->size() == 1) {
            chosen = it->first();
        } else {
            for (const KService::Ptr &service : *it) {
                if (service->desktopEntryName().endsWith(it.key(), Qt::CaseInsensitive)) {
                    chosen = service;
                    break;
                }
            }
        }
        if (chosen)
            m_apps.insert(it.key(), {chosen->name(), chosen->icon()});
    }
}

// What a process is called. The kernel's own name for it is cut at 15
// letters: where it is that long, the file it runs or its first argument
// gives the rest.
void Sampler::name(int pid, Known &known, const QByteArray &comm)
{
    known.comm = comm;
    known.path.clear();
    known.exe.clear();
    known.appName.clear();
    known.icon.clear();
    char path[64], target[4096];
    snprintf(path, sizeof path, "/proc/%d/exe", pid);
    const ssize_t length = readlink(path, target, sizeof target - 1);
    if (length > 0) {
        QString full = QString::fromLocal8Bit(target, length);
        if (full.endsWith(QLatin1String(" (deleted)")))
            full.chop(10);
        known.path = full;
        known.exe = full.section(QLatin1Char('/'), -1);
    }
    QString name = QString::fromUtf8(comm);
    if (comm.size() >= 15) {
        snprintf(path, sizeof path, "/proc/%d/cmdline", pid);
        const QByteArray line = slurp(path);
        const QString first = QString::fromLocal8Bit(line.constData()).section(QLatin1Char('/'), -1);
        if (known.exe.startsWith(name))
            name = known.exe;
        else if (first.startsWith(name) && !first.contains(QLatin1Char(' ')))
            name = first;
    }
    known.name = name;
    const auto app = m_apps.constFind(known.exe);
    if (app != m_apps.constEnd()) {
        known.appName = app->name;
        known.icon = app->icon;
    }
}

// Every connection's counters, and what each has carried since the last
// reading set aside for the process it turns out to belong to. One first
// seen is owed all it has carried so far.
void Sampler::readSockets()
{
    for (auto it = m_sockets.begin(); it != m_sockets.end(); ++it)
        it->seen = false;
    const auto take = [this](quint64 inode, const tcp_info &info, const QString &) {
        if (inode == 0)
            return;
        Socket &socket = m_sockets[inode];
        const quint64 sent = info.tcpi_bytes_acked, received = info.tcpi_bytes_received;
        const quint64 sentPackets = info.tcpi_segs_out, receivedPackets = info.tcpi_segs_in;
        if (sent < socket.sent || received < socket.received) {
            // The inode is another connection's now.
            socket = Socket();
        }
        socket.owedSent += sent - socket.sent;
        socket.owedReceived += received - socket.received;
        socket.owedSentPackets += sentPackets >= socket.sentPackets ? sentPackets - socket.sentPackets : 0;
        socket.owedReceivedPackets += receivedPackets >= socket.receivedPackets ? receivedPackets - socket.receivedPackets : 0;
        socket.sent = sent;
        socket.received = received;
        socket.sentPackets = sentPackets;
        socket.receivedPackets = receivedPackets;
        socket.seen = true;
    };
    connections(AF_INET, take);
    connections(AF_INET6, take);
    for (auto it = m_sockets.begin(); it != m_sockets.end();) {
        if (it->seen)
            ++it;
        else
            it = m_sockets.erase(it);
    }
}

// The processes holding the computer awake: logind's blocking inhibitors
// of sleep or of idling.
QSet<int> Sampler::awake() const
{
    QSet<int> holding;
    const QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.login1"), QStringLiteral("/org/freedesktop/login1"),
                                                             QStringLiteral("org.freedesktop.login1.Manager"), QStringLiteral("ListInhibitors"));
    const QDBusMessage reply = QDBusConnection::systemBus().call(call, QDBus::Block, 300);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
        return holding;
    const QDBusArgument list = reply.arguments().constFirst().value<QDBusArgument>();
    list.beginArray();
    while (!list.atEnd()) {
        QString what, who, why, mode;
        uint uid = 0, pid = 0;
        list.beginStructure();
        list >> what >> who >> why >> mode >> uid >> pid;
        list.endStructure();
        if (mode == QLatin1String("block") && (what.contains(QLatin1String("sleep")) || what.contains(QLatin1String("idle"))))
            holding.insert(int(pid));
    }
    list.endArray();
    return holding;
}

void Sampler::sample()
{
    const double seconds = m_first ? 0 : m_clock.nsecsElapsed() / 1e9;
    // Two readings on each other's heels (a tab changed as the timer
    // fired) would make rates of nothing: keep the one before.
    if (!m_first && seconds < 0.2)
        return;
    m_clock.start();
    m_first = false;

    struct Row {
        int pid = 0, ppid = 0, pgid = 0, threads = 0;
        uint uid = 0;
        double cpu = -1, cpuTime = 0, wakeups = -1;
        qint64 memory = 0, read = -1, written = -1;
        bool active = false, mine = false;
    };
    QList<Row> rows;
    Row kernel;
    bool kernelTimed = false;
    int allThreads = 0, count = 0;
    const uid_t self = geteuid();

    for (auto it = m_known.begin(); it != m_known.end(); ++it)
        it->seen = false;
    if (m_wantNetwork)
        readSockets();

    DIR *proc = opendir("/proc");
    if (!proc)
        return;
    char path[96], link[512];
    while (const dirent *entry = readdir(proc)) {
        if (entry->d_name[0] < '0' || entry->d_name[0] > '9')
            continue;
        const int pid = atoi(entry->d_name);
        snprintf(path, sizeof path, "/proc/%d/stat", pid);
        const QByteArray stat = slurp(path);
        const int open = stat.indexOf('('), close = stat.lastIndexOf(')');
        if (open < 0 || close < open)
            continue;
        const QByteArray comm = stat.mid(open + 1, close - open - 1);
        // From the state on: field n of proc(5) is fields[n - 3].
        const QList<QByteArray> fields = stat.mid(close + 2).split(' ');
        if (fields.size() < 22)
            continue;
        const quint64 ticks = fields[11].toULongLong() + fields[12].toULongLong();
        const quint64 start = fields[19].toULongLong();
        const int threads = fields[17].toInt();

        Known &known = m_known[pid];
        // A pid the kernel has given to another process starts over.
        const bool fresh = !known.measured || known.start != start;
        if (fresh) {
            known = Known();
            known.start = start;
            known.measured = true;
        }
        double cpu = -1;
        if (!fresh && seconds > 0 && ticks >= known.ticks)
            cpu = 100.0 * double(ticks - known.ticks) / double(m_tick) / seconds;
        known.ticks = ticks;
        known.seen = true;
        known.ppid = fields[1].toInt();
        allThreads += threads;
        ++count;

        if (fields[6].toULongLong() & KernelThread) {
            // One row for all of the kernel's threads.
            kernel.threads += 1;
            kernel.cpuTime += double(ticks) / double(m_tick);
            if (cpu >= 0) {
                kernel.cpu = (kernelTimed ? kernel.cpu : 0) + cpu;
                kernelTimed = true;
            }
            continue;
        }

        Row row;
        row.pid = pid;
        row.ppid = known.ppid;
        row.pgid = fields[2].toInt();
        row.threads = threads;
        row.cpu = cpu;
        row.cpuTime = double(ticks) / double(m_tick);
        row.active = cpu > 0 || fields[0] == "R";
        snprintf(path, sizeof path, "/proc/%d", pid);
        struct stat owner;
        row.uid = ::stat(path, &owner) == 0 ? owner.st_uid : 0;
        row.mine = row.uid == self || self == 0;
        if (known.comm != comm || known.name.isEmpty())
            name(pid, known, comm);

        // Its own memory: what it holds in RAM less what it shares.
        snprintf(path, sizeof path, "/proc/%d/statm", pid);
        const QList<QByteArray> pages = slurp(path).split(' ');
        if (pages.size() >= 3)
            row.memory = qMax<qint64>(0, pages[1].toLongLong() - pages[2].toLongLong()) * m_page;

        if (m_wantWakeups) {
            const qint64 switches = voluntarySwitches(pid, threads);
            if (switches >= 0 && known.switches >= 0 && seconds > 0)
                row.wakeups = double(qMax<qint64>(0, switches - known.switches)) / seconds;
            known.switches = switches;
        } else {
            known.switches = -1;
        }
        if (m_wantDisk) {
            snprintf(path, sizeof path, "/proc/%d/io", pid);
            const QByteArray io = slurp(path);
            row.read = after(io, "\nread_bytes:");
            row.written = after(io, "\nwrite_bytes:");
        }
        if (m_wantNetwork && row.mine) {
            // Which connections are its: the sockets among its open files.
            // One several processes hold goes to the first that had it.
            snprintf(path, sizeof path, "/proc/%d/fd", pid);
            if (DIR *files = opendir(path)) {
                while (const dirent *file = readdir(files)) {
                    if (file->d_name[0] == '.')
                        continue;
                    snprintf(path, sizeof path, "/proc/%d/fd/%s", pid, file->d_name);
                    const ssize_t length = readlink(path, link, sizeof link - 1);
                    if (length <= 0)
                        continue;
                    link[length] = 0;
                    const quint64 inode = socketInode(link);
                    if (inode == 0)
                        continue;
                    const auto socket = m_sockets.find(inode);
                    if (socket != m_sockets.end() && socket->pid < 0)
                        socket->pid = pid;
                }
                closedir(files);
            }
        }
        rows.append(row);
    }
    closedir(proc);

    for (auto it = m_known.begin(); it != m_known.end();) {
        if (it->seen)
            ++it;
        else
            it = m_known.erase(it);
    }
    // Each connection's traffic to the process it belongs to; one whose
    // process has gone is free for another that holds it.
    for (auto it = m_sockets.begin(); it != m_sockets.end(); ++it) {
        if (it->pid < 0)
            continue;
        const auto owner = m_known.find(it->pid);
        if (owner == m_known.end()) {
            it->pid = -1;
            continue;
        }
        owner->sent += qint64(it->owedSent);
        owner->received += qint64(it->owedReceived);
        owner->sentPackets += qint64(it->owedSentPackets);
        owner->receivedPackets += qint64(it->owedReceivedPackets);
        it->owedSent = it->owedReceived = it->owedSentPackets = it->owedReceivedPackets = 0;
    }

    m_system = machine(allThreads, count, seconds);
    const QSet<int> holding = m_wantSleep ? awake() : QSet<int>();

    QVariantList list;
    list.reserve(rows.size() + 1);
    if (kernel.threads > 0) {
        QVariantMap row;
        row.insert(QStringLiteral("pid"), 0);
        row.insert(QStringLiteral("ppid"), 0);
        row.insert(QStringLiteral("pgid"), 0);
        row.insert(QStringLiteral("uid"), 0);
        row.insert(QStringLiteral("user"), userName(0));
        row.insert(QStringLiteral("name"), QStringLiteral("kernel_task"));
        row.insert(QStringLiteral("icon"), QString());
        row.insert(QStringLiteral("threads"), kernel.threads);
        row.insert(QStringLiteral("cpu"), kernel.cpu);
        row.insert(QStringLiteral("cpuTime"), kernel.cpuTime);
        row.insert(QStringLiteral("active"), kernel.cpu > 0);
        row.insert(QStringLiteral("memory"), m_kernelMemory);
        row.insert(QStringLiteral("wakeups"), -1);
        row.insert(QStringLiteral("read"), -1);
        row.insert(QStringLiteral("written"), -1);
        row.insert(QStringLiteral("sent"), -1);
        row.insert(QStringLiteral("received"), -1);
        row.insert(QStringLiteral("sentPackets"), -1);
        row.insert(QStringLiteral("receivedPackets"), -1);
        row.insert(QStringLiteral("sleep"), false);
        list.append(row);
    }
    for (const Row &one : std::as_const(rows)) {
        const Known &known = m_known[one.pid];
        // An app's own process has its name and icon; the helpers it starts
        // from the same file keep the names they give themselves.
        const auto parent = m_known.constFind(one.ppid);
        const bool app = !known.appName.isEmpty() && (parent == m_known.constEnd() || parent->exe != known.exe);
        QVariantMap row;
        row.insert(QStringLiteral("pid"), one.pid);
        row.insert(QStringLiteral("ppid"), one.ppid);
        row.insert(QStringLiteral("pgid"), one.pgid);
        row.insert(QStringLiteral("uid"), one.uid);
        row.insert(QStringLiteral("user"), userName(one.uid));
        row.insert(QStringLiteral("name"), app ? known.appName : known.name);
        row.insert(QStringLiteral("icon"), app ? known.icon : QString());
        row.insert(QStringLiteral("threads"), one.threads);
        row.insert(QStringLiteral("cpu"), one.cpu);
        row.insert(QStringLiteral("cpuTime"), one.cpuTime);
        row.insert(QStringLiteral("active"), one.active);
        row.insert(QStringLiteral("memory"), one.memory);
        row.insert(QStringLiteral("wakeups"), one.wakeups);
        row.insert(QStringLiteral("read"), one.read);
        row.insert(QStringLiteral("written"), one.written);
        const bool counted = m_wantNetwork && one.mine;
        row.insert(QStringLiteral("sent"), counted ? known.sent : -1);
        row.insert(QStringLiteral("received"), counted ? known.received : -1);
        row.insert(QStringLiteral("sentPackets"), counted ? known.sentPackets : -1);
        row.insert(QStringLiteral("receivedPackets"), counted ? known.receivedPackets : -1);
        row.insert(QStringLiteral("sleep"), holding.contains(one.pid));
        list.append(row);
    }
    m_processes = list;
    Q_EMIT sampled();
}

// The whole machine's counters as the kernel keeps them (monitor.mjs makes
// shares and rates of them): cpu (the first line of /proc/stat), meminfo
// (kB, with ZramUsed), some and full (memory pressure, ten-second
// averages), the disks' reads, writes, readBytes and writtenBytes, the
// network's packetsIn, packetsOut, bytesIn and bytesOut, threads and
// count, and the seconds since the reading before.
QVariantMap Sampler::machine(int threads, int count, double seconds)
{
    QVariantMap all;
    all.insert(QStringLiteral("threads"), threads);
    all.insert(QStringLiteral("count"), count);
    all.insert(QStringLiteral("seconds"), seconds);

    QVariantList cpu;
    const QByteArray stat = slurp("/proc/stat");
    const QList<QByteArray> first = stat.left(stat.indexOf('\n')).simplified().split(' ');
    for (int i = 1; i < first.size() && i <= 8; ++i)
        cpu.append(first[i].toDouble());
    all.insert(QStringLiteral("cpu"), cpu);

    QVariantMap memory;
    const QList<QByteArray> lines = slurp("/proc/meminfo").split('\n');
    for (const QByteArray &line : lines) {
        const int colon = line.indexOf(':');
        if (colon > 0)
            memory.insert(QString::fromLatin1(line.left(colon)), strtod(line.constData() + colon + 1, nullptr));
    }
    double zram = 0;
    if (DIR *blocks = opendir("/sys/block")) {
        char path[96];
        while (const dirent *block = readdir(blocks)) {
            if (strncmp(block->d_name, "zram", 4) != 0)
                continue;
            snprintf(path, sizeof path, "/sys/block/%s/mm_stat", block->d_name);
            const QList<QByteArray> numbers = slurp(path).simplified().split(' ');
            if (numbers.size() >= 3)
                zram += numbers[2].toDouble() / 1024;
        }
        closedir(blocks);
    }
    memory.insert(QStringLiteral("ZramUsed"), zram);
    all.insert(QStringLiteral("meminfo"), memory);
    const auto kb = [&memory](const char *name) { return memory.value(QLatin1String(name)).toDouble(); };
    m_kernelMemory = qint64(kb("SUnreclaim") + kb("KernelStack") + kb("PageTables") + kb("Percpu")) * 1024;

    const QByteArray pressure = slurp("/proc/pressure/memory");
    const auto average = [&pressure](const char *kind) {
        const int line = pressure.indexOf(kind);
        const int at = line < 0 ? -1 : pressure.indexOf("avg10=", line);
        return at < 0 ? 0.0 : strtod(pressure.constData() + at + 6, nullptr);
    };
    all.insert(QStringLiteral("some"), average("some"));
    all.insert(QStringLiteral("full"), average("full"));

    // Whole disks only: a partition's traffic is its disk's too, and a
    // mapped or looped device's is that of the disk under it.
    double reads = 0, writes = 0, readSectors = 0, writtenSectors = 0;
    const QList<QByteArray> disks = slurp("/proc/diskstats").split('\n');
    for (const QByteArray &line : disks) {
        const QList<QByteArray> f = line.simplified().split(' ');
        if (f.size() < 10)
            continue;
        const QString name = QString::fromLatin1(f[2]);
        auto whole = m_disks.constFind(name);
        if (whole == m_disks.constEnd()) {
            static const char *const layered[] = {"loop", "ram", "zram", "dm-", "md", "sr", "fd"};
            bool real = access(("/sys/block/" + f[2]).constData(), F_OK) == 0;
            for (const char *prefix : layered)
                real = real && !f[2].startsWith(prefix);
            whole = m_disks.insert(name, real);
        }
        if (!*whole)
            continue;
        reads += f[3].toDouble();
        readSectors += f[5].toDouble();
        writes += f[7].toDouble();
        writtenSectors += f[9].toDouble();
    }
    all.insert(QStringLiteral("reads"), reads);
    all.insert(QStringLiteral("writes"), writes);
    all.insert(QStringLiteral("readBytes"), readSectors * 512);
    all.insert(QStringLiteral("writtenBytes"), writtenSectors * 512);

    double packetsIn = 0, packetsOut = 0, bytesIn = 0, bytesOut = 0;
    const QList<QByteArray> interfaces = slurp("/proc/net/dev").split('\n');
    for (const QByteArray &line : interfaces) {
        const int colon = line.indexOf(':');
        if (colon < 0 || line.left(colon).trimmed() == "lo")
            continue;
        const QList<QByteArray> f = line.mid(colon + 1).simplified().split(' ');
        if (f.size() < 10)
            continue;
        bytesIn += f[0].toDouble();
        packetsIn += f[1].toDouble();
        bytesOut += f[8].toDouble();
        packetsOut += f[9].toDouble();
    }
    all.insert(QStringLiteral("packetsIn"), packetsIn);
    all.insert(QStringLiteral("packetsOut"), packetsOut);
    all.insert(QStringLiteral("bytesIn"), bytesIn);
    all.insert(QStringLiteral("bytesOut"), bytesOut);
    return all;
}

QVariantMap Sampler::inspect(int pid)
{
    QVariantMap about;
    char path[96];
    snprintf(path, sizeof path, "/proc/%d/stat", pid);
    const QByteArray stat = slurp(path);
    const int close = stat.lastIndexOf(')');
    const QList<QByteArray> fields = close < 0 ? QList<QByteArray>() : stat.mid(close + 2).split(' ');
    if (fields.size() < 22) {
        about.insert(QStringLiteral("gone"), true);
        return about;
    }
    const auto called = [this](int id) {
        if (id == 0)
            return QStringLiteral("kernel_task (0)");
        const auto known = m_known.constFind(id);
        const QString name = known == m_known.constEnd() ? QString() : (known->appName.isEmpty() ? known->name : known->appName);
        return name.isEmpty() ? QString::number(id) : QStringLiteral("%1 (%2)").arg(name).arg(id);
    };
    const int ppid = fields[1].toInt();
    const auto known = m_known.constFind(pid);
    about.insert(QStringLiteral("gone"), false);
    about.insert(QStringLiteral("exe"), known == m_known.constEnd() ? QString() : known->path);
    about.insert(QStringLiteral("parent"), called(ppid));
    about.insert(QStringLiteral("parentPid"), ppid);
    about.insert(QStringLiteral("group"), called(fields[2].toInt()));
    snprintf(path, sizeof path, "/proc/%d", pid);
    struct stat owner;
    const uint uid = ::stat(path, &owner) == 0 ? owner.st_uid : 0;
    about.insert(QStringLiteral("user"), QStringLiteral("%1 (%2)").arg(userName(uid)).arg(uid));
    const int threads = fields[17].toInt();
    about.insert(QStringLiteral("threads"), threads);
    about.insert(QStringLiteral("cpuTime"), double(fields[11].toULongLong() + fields[12].toULongLong()) / double(m_tick));
    const double minor = fields[7].toDouble(), major = fields[9].toDouble();
    about.insert(QStringLiteral("faults"), minor + major);
    about.insert(QStringLiteral("pageIns"), major);
    about.insert(QStringLiteral("vsize"), fields[20].toDouble());
    snprintf(path, sizeof path, "/proc/%d/statm", pid);
    const QList<QByteArray> pages = slurp(path).split(' ');
    const double resident = pages.size() >= 3 ? pages[1].toDouble() * m_page : 0;
    const double shared = pages.size() >= 3 ? pages[2].toDouble() * m_page : 0;
    about.insert(QStringLiteral("rss"), resident);
    about.insert(QStringLiteral("shared"), shared);
    about.insert(QStringLiteral("own"), qMax(0.0, resident - shared));
    // Every switch, asked for or not, of every thread.
    double switches = 0;
    snprintf(path, sizeof path, "/proc/%d/task", pid);
    if (DIR *tasks = opendir(path)) {
        while (const dirent *task = readdir(tasks)) {
            if (task->d_name[0] < '0' || task->d_name[0] > '9')
                continue;
            snprintf(path, sizeof path, "/proc/%d/task/%s/status", pid, task->d_name);
            const QByteArray status = slurp(path);
            switches += qMax<qint64>(0, after(status, "\nvoluntary_ctxt_switches:")) + qMax<qint64>(0, after(status, "\nnonvoluntary_ctxt_switches:"));
        }
        closedir(tasks);
    }
    about.insert(QStringLiteral("switches"), switches);
    return about;
}

QString Sampler::openFiles(int pid)
{
    char path[96], link[4096];
    QStringList lines;
    const auto target = [&](const char *name) -> QString {
        snprintf(path, sizeof path, "/proc/%d/%s", pid, name);
        const ssize_t length = readlink(path, link, sizeof link - 1);
        return length > 0 ? QString::fromLocal8Bit(link, length) : QString();
    };
    const QString cwd = target("cwd");
    if (cwd.isEmpty())
        return {};
    lines << QStringLiteral("cwd") << cwd;
    const QString exe = target("exe");
    if (!exe.isEmpty())
        lines << QStringLiteral("txt") << exe;

    QHash<quint64, QString> ends;
    const auto note = [&ends](quint64 inode, const tcp_info &, const QString &where) { ends.insert(inode, where); };
    connections(AF_INET, note);
    connections(AF_INET6, note);

    QList<int> numbers;
    snprintf(path, sizeof path, "/proc/%d/fd", pid);
    if (DIR *files = opendir(path)) {
        while (const dirent *file = readdir(files)) {
            if (file->d_name[0] >= '0' && file->d_name[0] <= '9')
                numbers.append(atoi(file->d_name));
        }
        closedir(files);
    }
    std::sort(numbers.begin(), numbers.end());
    for (const int number : std::as_const(numbers)) {
        char name[32];
        snprintf(name, sizeof name, "fd/%d", number);
        QString what = target(name);
        if (what.isEmpty())
            continue;
        const quint64 inode = socketInode(what.toLocal8Bit().constData());
        if (inode != 0 && ends.contains(inode))
            what = ends.value(inode);
        lines << QString::number(number) << what;
    }
    return lines.join(QLatin1Char('\n'));
}

int Sampler::quit(int pid, bool force)
{
    if (pid <= 1)
        return EPERM;
    if (::kill(pid, force ? SIGKILL : SIGTERM) == 0) {
        QTimer::singleShot(600, this, &Sampler::sample);
        return 0;
    }
    return errno;
}

void Sampler::quitAsAdministrator(int pid, bool force)
{
    if (pid <= 1)
        return;
    // polkit asks for an administrator's password (the shell's own prompt).
    QProcess::startDetached(QStringLiteral("pkexec"), {QStringLiteral("kill"), QStringLiteral("-s"), force ? QStringLiteral("KILL") : QStringLiteral("TERM"), QString::number(pid)});
    QTimer::singleShot(4000, this, &Sampler::sample);
}
