// screenrec OUT.mp4 [SECONDS]: records the screen, pointer included, to an
// H.264 file until SIGINT/SIGTERM (or SECONDS). It asks the desktop portal
// for the screen; the first run shows the portal's share dialog, later runs
// reuse its restore token (~/.cache/screenrec-token).
#include <PipeWireRecord>

#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusUnixFileDescriptor>
#include <QDir>
#include <QFileInfo>
#include <QFile>
#include <QGuiApplication>
#include <QSocketNotifier>
#include <QStandardPaths>
#include <QTimer>

#include <csignal>
#include <cstdio>
#include <functional>
#include <sys/socket.h>
#include <unistd.h>

namespace {

const QString service = QStringLiteral("org.freedesktop.portal.Desktop");
const QString path = QStringLiteral("/org/freedesktop/portal/desktop");
const QString iface = QStringLiteral("org.freedesktop.portal.ScreenCast");
int signalPipe[2];
int counter = 0;

class Receiver : public QObject
{
    Q_OBJECT
public:
    std::function<void(uint, const QVariantMap &)> fn;
public Q_SLOTS:
    void response(uint code, const QVariantMap &results) { fn(code, results); }
};

QString tokenFile()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/screenrec-token");
}

// Calls a portal method that answers through a Request object's Response.
void request(const QString &method, QVariantList args, QVariantMap options, std::function<void(QVariantMap)> done)
{
    auto bus = QDBusConnection::sessionBus();
    const QString token = QStringLiteral("screenrec%1").arg(++counter);
    options.insert(QStringLiteral("handle_token"), token);
    const QString sender = bus.baseService().mid(1).replace(QLatin1Char('.'), QLatin1Char('_'));
    const QString requestPath = QStringLiteral("/org/freedesktop/portal/desktop/request/%1/%2").arg(sender, token);
    auto *receiver = new Receiver;
    receiver->fn = [done, receiver, method](uint code, const QVariantMap &results) {
        receiver->deleteLater();
        if (code != 0) {
            std::fprintf(stderr, "screenrec: %s was refused (%u)\n", qPrintable(method), code);
            QCoreApplication::exit(1);
            return;
        }
        done(results);
    };
    bus.connect(service, requestPath, QStringLiteral("org.freedesktop.portal.Request"), QStringLiteral("Response"), receiver,
                SLOT(response(uint, QVariantMap)));
    args << options;
    auto msg = QDBusMessage::createMethodCall(service, path, iface, method);
    msg.setArguments(args);
    const QDBusMessage reply = bus.call(msg);
    if (reply.type() == QDBusMessage::ErrorMessage) {
        std::fprintf(stderr, "screenrec: %s: %s\n", qPrintable(method), qPrintable(reply.errorMessage()));
        QCoreApplication::exit(1);
    }
}

}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    if (argc < 2) {
        std::fprintf(stderr, "usage: screenrec OUT.mp4 [SECONDS]\n");
        return 2;
    }
    const QString out = QString::fromLocal8Bit(argv[1]);
    const int seconds = argc > 2 ? atoi(argv[2]) : 0;

    auto *record = new PipeWireRecord(&app);
    record->setEncoder(PipeWireBaseEncodedStream::H264Main);
    record->setMaxFramerate(30);
    record->setOutput(out);
    QObject::connect(record, &PipeWireBaseEncodedStream::stateChanged, &app, [record] {
        if (record->state() == PipeWireBaseEncodedStream::Recording)
            std::fprintf(stderr, "screenrec: recording\n");
        if (record->state() == PipeWireBaseEncodedStream::Idle && record->property("stopping").toBool())
            QCoreApplication::quit();
    });
    auto stop = [record] {
        if (record->property("stopping").toBool())
            return;
        record->setProperty("stopping", true);
        if (record->state() == PipeWireBaseEncodedStream::Idle)
            QCoreApplication::quit();
        else
            record->stop();
    };

    // SIGINT and SIGTERM stop the recording cleanly.
    ::socketpair(AF_UNIX, SOCK_STREAM, 0, signalPipe);
    auto *notifier = new QSocketNotifier(signalPipe[1], QSocketNotifier::Read, &app);
    QObject::connect(notifier, &QSocketNotifier::activated, &app, stop);
    std::signal(SIGINT, [](int) { char c = 1; (void)::write(signalPipe[0], &c, 1); });
    std::signal(SIGTERM, [](int) { char c = 1; (void)::write(signalPipe[0], &c, 1); });
    if (seconds > 0)
        QTimer::singleShot(seconds * 1000, &app, stop);

    QVariantMap create{{QStringLiteral("session_handle_token"), QStringLiteral("screenrec")}};
    request(QStringLiteral("CreateSession"), {}, create, [record](QVariantMap r) {
        const QDBusObjectPath session(r.value(QStringLiteral("session_handle")).toString());
        QFile saved(tokenFile());
        QVariantMap select{{QStringLiteral("types"), 1u}, {QStringLiteral("cursor_mode"), 2u}, {QStringLiteral("persist_mode"), 2u}};
        if (saved.open(QIODevice::ReadOnly))
            select.insert(QStringLiteral("restore_token"), QString::fromUtf8(saved.readAll().trimmed()));
        request(QStringLiteral("SelectSources"), {QVariant::fromValue(session)}, select, [record, session](QVariantMap) {
            request(QStringLiteral("Start"), {QVariant::fromValue(session), QString()}, {}, [record, session](QVariantMap r) {
                if (const QString token = r.value(QStringLiteral("restore_token")).toString(); !token.isEmpty()) {
                    QDir().mkpath(QFileInfo(tokenFile()).path());
                    QFile f(tokenFile());
                    if (f.open(QIODevice::WriteOnly))
                        f.write(token.toUtf8());
                }
                uint node = 0;
                const QDBusArgument streams = r.value(QStringLiteral("streams")).value<QDBusArgument>();
                streams.beginArray();
                if (!streams.atEnd()) {
                    streams.beginStructure();
                    QVariantMap props;
                    streams >> node >> props;
                    streams.endStructure();
                }
                streams.endArray();
                auto msg = QDBusMessage::createMethodCall(service, path, iface, QStringLiteral("OpenPipeWireRemote"));
                msg.setArguments({QVariant::fromValue(session), QVariantMap()});
                const QDBusMessage reply = QDBusConnection::sessionBus().call(msg);
                const auto fd = qdbus_cast<QDBusUnixFileDescriptor>(reply.arguments().value(0));
                record->setFd(::dup(fd.fileDescriptor()));
                // The portal gives a node id; KPipeWire would rather have a serial.
                QT_WARNING_PUSH
                QT_WARNING_DISABLE_DEPRECATED
                record->setNodeId(node);
                QT_WARNING_POP
                std::fprintf(stderr, "screenrec: node %u\n", node);
                record->start();
            });
        });
    });
    return app.exec();
}

#include "main.moc"
