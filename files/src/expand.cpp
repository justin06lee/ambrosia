#include "expand.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QMimeDatabase>
#include <QMutex>
#include <QStringDecoder>
#include <QTemporaryDir>
#include <QtConcurrentRun>

#include <KZip>

#include <QDirIterator>

#include <archive.h>
#include <archive_entry.h>

#include <sys/stat.h>

namespace {

// An entry's path as the archive gives it, made safe to put under a folder
// of ours: no leading slash, no "." steps; empty for one that climbs out
// with "..", which is not expanded at all.
QString safePath(const QString &path)
{
    QStringList steps;
    for (const QString &step : path.split(QLatin1Char('/'), Qt::SkipEmptyParts)) {
        if (step == QLatin1String("."))
            continue;
        if (step == QLatin1String(".."))
            return {};
        steps << step;
    }
    return steps.join(QLatin1Char('/'));
}

// The entry's name: UTF-8 where the archive says so or the bytes are; an
// old zip's bytes in no known encoding are read one byte a letter, so the
// file at least arrives.
QString entryPath(struct archive_entry *entry)
{
    if (const char *utf8 = archive_entry_pathname_utf8(entry))
        return QString::fromUtf8(utf8);
    const char *raw = archive_entry_pathname(entry);
    if (!raw)
        return {};
    QStringDecoder decoder(QStringDecoder::Utf8);
    const QString text = decoder(QByteArrayView(raw));
    return decoder.hasError() ? QString::fromLatin1(raw) : text;
}

// "notes", then "notes 2", "notes 3"; a file's number goes before its
// extension ("notes 2.txt"), as Finder numbers them.
QString freeName(const QDir &dir, const QString &name, bool isDir)
{
    if (!QFileInfo::exists(dir.filePath(name)) && !QFileInfo(dir.filePath(name)).isSymLink())
        return name;
    QString base = name, ext;
    if (!isDir) {
        const QString suffix = QMimeDatabase().suffixForFileName(name);
        const int dot = suffix.isEmpty() ? name.lastIndexOf(QLatin1Char('.')) : name.size() - suffix.size() - 1;
        if (dot > 0) {
            base = name.left(dot);
            ext = name.mid(dot);
        }
    }
    for (int n = 2;; ++n) {
        const QString candidate = QStringLiteral("%1 %2%3").arg(base).arg(n).arg(ext);
        if (!QFileInfo::exists(dir.filePath(candidate)) && !QFileInfo(dir.filePath(candidate)).isSymLink())
            return candidate;
    }
}

// The archive's name without what makes it an archive: "site" for
// site.tar.gz, "notes.txt" for notes.txt.gz.
QString stemOf(const QString &name)
{
    const QString suffix = QMimeDatabase().suffixForFileName(name);
    if (!suffix.isEmpty() && name.size() > suffix.size() + 1)
        return name.left(name.size() - suffix.size() - 1);
    const int dot = name.lastIndexOf(QLatin1Char('.'));
    return dot > 0 ? name.left(dot) : name;
}

// What went wrong, in libarchive's own words where it has any. A password
// wanted (a zip's: libarchive says "passphrase") is `locked`, to be asked
// for; one it has no way to use (7z's, rar's) is said in our words.
QString why(struct archive *a, const QString &otherwise, bool *locked = nullptr)
{
    const char *text = archive_error_string(a);
    const QString said = text && *text ? QString::fromUtf8(text) : otherwise;
    if (said.contains(QLatin1String("assphrase"))) {
        if (locked)
            *locked = true;
        return QStringLiteral("It is protected by a password.");
    }
    if (said.contains(QLatin1String("ncrypt")))
        return QStringLiteral("It is protected by a password in a way Files can’t open.");
    return said;
}

}

ExpandJob::Result ExpandJob::expand(const QString &archive, const QString &password, const std::shared_ptr<State> &state)
{
    Result result;
    const QFileInfo info(archive);
    // The folder by its real path: nothing is expanded through a link, and
    // a link on the way to the folder itself must not count as one.
    const QDir dir(info.canonicalPath());
    if (!info.isFile() || !dir.exists()) {
        result.error = QStringLiteral("The archive can’t be read.");
        return result;
    }
    // Everything lands in a folder of its own beside the archive first,
    // hidden by its name, and takes its place once it is whole.
    QTemporaryDir work(dir.filePath(QStringLiteral(".expanding-XXXXXX")));
    if (!work.isValid()) {
        result.error = QStringLiteral("The folder it is in can’t be written to.");
        return result;
    }
    const QString root = work.path();

    struct archive *in = archive_read_new();
    archive_read_support_filter_all(in);
    // The kinds by name, not "all": that takes mtree, which reads any text
    // as a list of files to make (a gzipped note came out as empty files
    // named by its words).
    archive_read_support_format_zip(in);
    archive_read_support_format_tar(in);
    archive_read_support_format_gnutar(in);
    archive_read_support_format_7zip(in);
    archive_read_support_format_rar(in);
    archive_read_support_format_rar5(in);
    archive_read_support_format_cpio(in);
    archive_read_support_format_lha(in);
    archive_read_support_format_cab(in);
    archive_read_support_format_xar(in);
    archive_read_support_format_raw(in); // a lone file, compressed
    if (!password.isEmpty())
        archive_read_add_passphrase(in, password.toUtf8().constData());
    struct archive *out = archive_write_disk_new();
    archive_write_disk_set_options(out, ARCHIVE_EXTRACT_TIME | ARCHIVE_EXTRACT_PERM | ARCHIVE_EXTRACT_SECURE_NODOTDOT | ARCHIVE_EXTRACT_SECURE_SYMLINKS);

    bool ok = archive_read_open_filename(in, QFile::encodeName(archive).constData(), 1 << 16) == ARCHIVE_OK;
    if (!ok)
        result.error = why(in, QStringLiteral("It isn’t an archive this computer can read."));
    bool stopped = false;
    while (ok) {
        struct archive_entry *entry = nullptr;
        const int next = archive_read_next_header(in, &entry);
        if (next == ARCHIVE_EOF)
            break;
        if (next < ARCHIVE_WARN) {
            ok = false;
            result.error = why(in, QStringLiteral("The archive is damaged."), &result.locked);
            break;
        }
        if (state->stop.load()) {
            stopped = true;
            break;
        }
        // Closed with a password and none given: nothing is tried.
        if (password.isEmpty() && archive_entry_is_data_encrypted(entry) == 1 && archive_format(in) == ARCHIVE_FORMAT_ZIP) {
            ok = false;
            result.locked = true;
            result.error = QStringLiteral("It is protected by a password.");
            break;
        }
        const bool raw = archive_format(in) == ARCHIVE_FORMAT_RAW;
        // Any file at all reads as "a lone file": it is one only if
        // something had compressed it.
        if (raw && archive_filter_count(in) < 2) {
            ok = false;
            result.error = QStringLiteral("It isn’t an archive this computer can read.");
            break;
        }
        const QString path = safePath(raw ? stemOf(info.fileName()) : entryPath(entry));
        if (path.isEmpty())
            continue; // the archive's own top, or a path out of it
        archive_entry_copy_pathname(entry, QFile::encodeName(root + QLatin1Char('/') + path).constData());
        // A hard link names another entry: it must stay inside too.
        if (const char *link = archive_entry_hardlink(entry)) {
            const QString target = safePath(QString::fromUtf8(link));
            if (target.isEmpty())
                continue;
            archive_entry_copy_hardlink(entry, QFile::encodeName(root + QLatin1Char('/') + target).constData());
        }
        const int header = archive_write_header(out, entry);
        if (header < ARCHIVE_WARN) {
            // One entry refused (through a link, a name the disk won't
            // take): the rest still come, and the whole is said to have
            // failed only if the disk itself gave up.
            if (header <= ARCHIVE_FATAL) {
                ok = false;
                result.error = why(out, QStringLiteral("The disk can’t be written to."));
                break;
            }
            continue;
        }
        for (;;) {
            const void *block = nullptr;
            size_t size = 0;
            la_int64_t offset = 0;
            const int read = archive_read_data_block(in, &block, &size, &offset);
            if (read == ARCHIVE_EOF)
                break;
            if (read < ARCHIVE_WARN) {
                ok = false;
                result.error = why(in, QStringLiteral("The archive is damaged."), &result.locked);
                break;
            }
            if (archive_write_data_block(out, block, size, offset) < ARCHIVE_WARN) {
                ok = false;
                result.error = why(out, QStringLiteral("The disk may be full."));
                break;
            }
            state->read.store(archive_filter_bytes(in, -1));
            if (state->stop.load()) {
                stopped = true;
                break;
            }
        }
        if (!ok || stopped)
            break;
        archive_write_finish_entry(out);
    }
    archive_read_free(in);
    // Folders get their dates and permissions here, by their paths: before
    // anything is moved.
    archive_write_free(out);
    if (!ok || stopped)
        return result; // the work folder goes with `work`

    // One at a time from here: two archives done at once must not both
    // find the same name free.
    static QMutex placing;
    const QMutexLocker locker(&placing);
    QDir made(root);
    // What a Mac's own zips carry for itself is not the user's.
    QDir(made.filePath(QStringLiteral("__MACOSX"))).removeRecursively();
    QFile::remove(made.filePath(QStringLiteral(".DS_Store")));
    const QStringList items = made.entryList(QDir::AllEntries | QDir::Hidden | QDir::System | QDir::NoDotAndDotDot);
    if (items.isEmpty()) {
        result.error = QStringLiteral("There is nothing in it.");
        return result;
    }
    if (items.size() == 1) {
        const QString from = made.filePath(items.first());
        const QFileInfo item(from);
        const QString to = dir.filePath(freeName(dir, items.first(), item.isDir() && !item.isSymLink()));
        if (!QDir().rename(from, to)) {
            result.error = QStringLiteral("The folder it is in can’t be written to.");
            return result;
        }
        result.made = to;
    } else {
        const QString to = dir.filePath(freeName(dir, stemOf(info.fileName()), true));
        if (!QDir().rename(root, to)) {
            result.error = QStringLiteral("The folder it is in can’t be written to.");
            return result;
        }
        work.setAutoRemove(false);
        // The work folder was the user's alone; a folder is everyone's to read.
        QFile::setPermissions(to, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner | QFileDevice::ReadGroup | QFileDevice::ExeGroup
                                      | QFileDevice::ReadOther | QFileDevice::ExeOther);
        result.made = to;
    }
    result.ok = true;
    return result;
}

ExpandJob::ExpandJob(const QString &archive, const QString &password, QObject *parent)
    : KJob(parent)
    , m_archive(archive)
    , m_password(password)
    , m_state(std::make_shared<State>())
{
    setCapabilities(Killable);
    m_tick.setInterval(200);
    connect(&m_tick, &QTimer::timeout, this, [this] { setProcessedAmount(Bytes, qulonglong(m_state->read.load())); });
}

void ExpandJob::start()
{
    setTotalAmount(Bytes, qulonglong(QFileInfo(m_archive).size()));
    m_tick.start();
    // The watcher goes with the job: a job that was stopped is gone by the
    // time its thread, told to stop, has cleared up after itself.
    auto *watcher = new QFutureWatcher<Result>(this);
    connect(watcher, &QFutureWatcher<Result>::finished, this, [this, watcher] {
        const Result result = watcher->result();
        m_tick.stop();
        if (result.ok) {
            m_made = result.made;
            setProcessedAmount(Bytes, totalAmount(Bytes));
        } else {
            m_locked = result.locked;
            setError(UserDefinedError);
            setErrorText(result.error);
        }
        emitResult();
    });
    watcher->setFuture(QtConcurrent::run([archive = m_archive, password = m_password, state = m_state] { return expand(archive, password, state); }));
}

bool ExpandJob::doKill()
{
    m_state->stop.store(true);
    m_tick.stop();
    return true;
}

namespace {

// One item into the zip under `name`, a folder with all that is in it.
bool zipOne(KZip &zip, const QString &path, const QString &name, CompressJob::State &state)
{
    if (state.stop.load())
        return false;
    const QFileInfo info(path);
    struct stat st;
    if (::lstat(QFile::encodeName(path).constData(), &st) != 0)
        return false;
    if (info.isSymLink())
        return zip.addLocalFile(path, name);
    if (info.isDir()) {
        // The folder itself, so that an empty one is kept.
        if (!zip.writeDir(name, info.owner(), info.group(), st.st_mode, info.lastRead(), info.lastModified(), info.birthTime()))
            return false;
        const QStringList inside = QDir(path).entryList(QDir::AllEntries | QDir::Hidden | QDir::System | QDir::NoDotAndDotDot, QDir::Name);
        for (const QString &one : inside) {
            if (!zipOne(zip, path + QLatin1Char('/') + one, name + QLatin1Char('/') + one, state))
                return false;
        }
        return true;
    }
    if (!info.isFile())
        return true; // (a socket, a pipe: left out, as Finder leaves them)
    // A megabyte at a time, so a large file can be seen going in and
    // stopped partway.
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return false;
    if (!zip.prepareWriting(name, info.owner(), info.group(), file.size(), st.st_mode, info.lastRead(), info.lastModified(), info.birthTime()))
        return false;
    QByteArray block(1024 * 1024, Qt::Uninitialized);
    qint64 put = 0;
    while (true) {
        if (state.stop.load())
            return false;
        const qint64 n = file.read(block.data(), block.size());
        if (n < 0)
            return false;
        if (n == 0)
            break;
        if (!zip.writeData(block.constData(), n))
            return false;
        put += n;
        state.done.fetch_add(n);
    }
    return zip.finishWriting(put);
}

} // namespace

qint64 CompressJob::sizeOf(const QStringList &paths)
{
    qint64 size = 0;
    for (const QString &path : paths) {
        const QFileInfo info(path);
        if (info.isSymLink())
            continue;
        if (info.isFile()) {
            size += info.size();
            continue;
        }
        QDirIterator it(path, QDir::Files | QDir::Hidden | QDir::System | QDir::NoSymLinks, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            size += it.fileInfo().size();
        }
    }
    return size;
}

bool CompressJob::compress(const QStringList &paths, const QString &to, const std::shared_ptr<State> &state)
{
    const QFileInfo target(to);
    const QString part = target.dir().filePath(QStringLiteral(".%1.part").arg(target.fileName()));
    bool ok = false;
    {
        KZip zip(part);
        if (zip.open(QIODevice::WriteOnly)) {
            ok = true;
            for (const QString &path : paths)
                ok = ok && zipOne(zip, path, QFileInfo(path).fileName(), *state);
            ok = zip.close() && ok;
        }
    }
    ok = ok && !state->stop.load() && QFile::rename(part, to);
    if (!ok)
        QFile::remove(part);
    return ok;
}

CompressJob::CompressJob(const QStringList &paths, const QString &to, QObject *parent)
    : KJob(parent)
    , m_paths(paths)
    , m_to(to)
    , m_state(std::make_shared<State>())
{
    setCapabilities(Killable);
    m_tick.setInterval(200);
    connect(&m_tick, &QTimer::timeout, this, [this] { setProcessedAmount(Bytes, qulonglong(m_state->done.load())); });
}

void CompressJob::start()
{
    m_tick.start();
    // (The watcher goes with the job, as ExpandJob's.) How much there is
    // is counted on the thread too: a folder of many files takes a while
    // to add up.
    auto *sized = new QFutureWatcher<qint64>(this);
    connect(sized, &QFutureWatcher<qint64>::finished, this, [this, sized] { setTotalAmount(Bytes, qulonglong(sized->result())); });
    sized->setFuture(QtConcurrent::run([paths = m_paths] { return sizeOf(paths); }));
    auto *watcher = new QFutureWatcher<bool>(this);
    connect(watcher, &QFutureWatcher<bool>::finished, this, [this, watcher] {
        m_tick.stop();
        if (watcher->result()) {
            setProcessedAmount(Bytes, totalAmount(Bytes));
        } else {
            setError(UserDefinedError);
            setErrorText(QStringLiteral("The folder may not be one you can write to, or the disk may be full."));
        }
        emitResult();
    });
    watcher->setFuture(QtConcurrent::run([paths = m_paths, to = m_to, state = m_state] { return compress(paths, to, state); }));
}

bool CompressJob::doKill()
{
    m_state->stop.store(true);
    m_tick.stop();
    return true;
}
