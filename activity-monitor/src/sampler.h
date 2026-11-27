#pragma once

#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

// What the computer is doing, read from the kernel every few seconds: each
// process (/proc/PID) and the whole machine's counters (/proc/stat,
// meminfo, diskstats, net/dev). It only reads and counts; what the numbers
// mean, their order and their words are qml/monitor.mjs's.
//
// A process is a map: pid, ppid, pgid, uid, user, name, icon (a theme icon's
// name, for an app's own process), threads, cpu (percent of one core, -1
// before a second reading), cpuTime (seconds), active, memory (bytes its
// own: resident less shared), and, read only while a tab asks for them,
// wakeups (a second, -1 unknown), read and written (bytes, -1 where the
// kernel won't say: another user's process), sent, received, sentPackets,
// receivedPackets (TCP, -1 likewise), sleep (holds the computer awake).
// The kernel's own threads are one row, kernel_task, as on a Mac.
class Sampler : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantList processes READ processes NOTIFY sampled)
    Q_PROPERTY(QVariantMap system READ system NOTIFY sampled)
    // Milliseconds between readings.
    Q_PROPERTY(int interval READ interval WRITE setInterval NOTIFY intervalChanged)
    // What the tab in view needs beyond the cheap readings.
    Q_PROPERTY(bool wakeups MEMBER m_wantWakeups NOTIFY wantsChanged)
    Q_PROPERTY(bool disk MEMBER m_wantDisk NOTIFY wantsChanged)
    Q_PROPERTY(bool network MEMBER m_wantNetwork NOTIFY wantsChanged)
    Q_PROPERTY(bool sleep MEMBER m_wantSleep NOTIFY wantsChanged)
    // The user's own id.
    Q_PROPERTY(int me READ me CONSTANT)

public:
    explicit Sampler(QObject *parent = nullptr);

    QVariantList processes() const { return m_processes; }
    QVariantMap system() const { return m_system; }
    int interval() const { return m_timer.interval(); }
    void setInterval(int milliseconds);
    int me() const;

    // Read now (and start the clock again).
    Q_INVOKABLE void sample();
    // One process in full, for its inspector: exe, parent and parentPid,
    // group, user, cpu, rss, vsize, shared, own (bytes), threads, cpuTime,
    // switches, faults, pageIns; `gone` when it has ended.
    Q_INVOKABLE QVariantMap inspect(int pid);
    // Its open files as a Mac lists them: a descriptor, then what it is.
    // Empty for a process the kernel won't show us.
    Q_INVOKABLE QString openFiles(int pid);
    // Ask it to quit, or end it at once. 0, or the kernel's error (EPERM
    // for another user's: quitAsAdministrator then).
    Q_INVOKABLE int quit(int pid, bool force);
    Q_INVOKABLE void quitAsAdministrator(int pid, bool force);

Q_SIGNALS:
    void sampled();
    void intervalChanged();
    void wantsChanged();

private:
    struct Known {
        quint64 start = 0;       // when it began, in ticks: tells a pid used again
        quint64 ticks = 0;       // processor time at the last reading
        qint64 switches = -1;    // voluntary switches at the last reading
        QByteArray comm;
        QString exe;             // the file it runs, its last part
        QString path;            // the file it runs, in full ("" when hidden)
        QString appName;         // an app's name and icon, when its file is one's
        QString icon;
        QString name;            // what it is called without those
        qint64 sent = 0, received = 0, sentPackets = 0, receivedPackets = 0;
        int ppid = 0;
        bool seen = false;
        bool measured = false;
    };
    // A TCP connection: its counters at the last reading, what it has
    // carried that no process has been credited with yet, and whose it is.
    struct Socket {
        quint64 sent = 0, received = 0, sentPackets = 0, receivedPackets = 0;
        quint64 owedSent = 0, owedReceived = 0, owedSentPackets = 0, owedReceivedPackets = 0;
        int pid = -1;
        bool seen = false;
    };
    struct AppEntry {
        QString name;
        QString icon;
    };

    void name(int pid, Known &known, const QByteArray &comm);
    QString userName(uint uid);
    void readApps();
    void readSockets();
    QSet<int> awake() const;
    QVariantMap machine(int threads, int count, double seconds);

    QTimer m_timer;
    QElapsedTimer m_clock;
    bool m_first = true;
    QVariantList m_processes;
    QVariantMap m_system;
    QHash<int, Known> m_known;
    QHash<quint64, Socket> m_sockets;
    QHash<uint, QString> m_users;
    QHash<QString, AppEntry> m_apps;
    QHash<QString, bool> m_disks;
    qint64 m_kernelMemory = 0;
    bool m_wantWakeups = true;
    bool m_wantDisk = false;
    bool m_wantNetwork = false;
    bool m_wantSleep = false;
    long m_tick = 100;
    long m_page = 4096;
};
