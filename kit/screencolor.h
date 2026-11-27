#pragma once

#include <QColor>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QObject>
#include <QtQml/qqmlregistration.h>

// A color off the screen, for the Colors panel's eyedropper (Colors.qml):
// KWin's own picker, asked over the session bus. The pointer becomes a
// cross and the next click anywhere says `picked`; Escape gives it up and
// nothing is said. An app that shows the panel lists this header among its
// QML module's sources.
class ScreenColor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    Q_INVOKABLE void pick()
    {
        const QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/ColorPicker"),
                                                                 QStringLiteral("org.kde.kwin.ColorPicker"), QStringLiteral("pick"));
        // (However long the choosing takes.)
        auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(call, 10 * 60 * 1000), this);
        connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *done) {
            done->deleteLater();
            const QDBusMessage reply = done->reply();
            if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty())
                return;
            // KWin sends a color as a structure of one number, 0xAARRGGBB.
            const QDBusArgument sent = reply.arguments().constFirst().value<QDBusArgument>();
            uint rgba = 0;
            sent.beginStructure();
            sent >> rgba;
            sent.endStructure();
            Q_EMIT picked(QColor::fromRgba(rgba));
        });
    }

Q_SIGNALS:
    void picked(const QColor &color);
};
