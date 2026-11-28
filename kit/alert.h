#pragma once

#include <QObject>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QString>
#include <QVariantMap>

#include <functional>

// An alert raised from C++ (the kit's AlertWindow.qml, which the app lists
// among its QML module's files along with this header): kitAlert(engine,
// "Files", { icon, heading, detail, buttons, secret }, then). `buttons` is
// a list of maps { text, role, primary, cancel }, OK alone when left out;
// `then` hears the role pressed and what was typed (a `secret` one asks
// for a password). False when the alert couldn't be made: the caller says
// it some other way.
class AlertAnswer : public QObject
{
    Q_OBJECT

public:
    using Then = std::function<void(const QString &role, const QString &typed)>;
    AlertAnswer(Then then, QObject *parent)
        : QObject(parent)
        , m_then(std::move(then))
    {
    }

public Q_SLOTS:
    void take(const QString &role, const QString &typed)
    {
        // The window (our parent) goes once this has run.
        parent()->deleteLater();
        if (m_then)
            m_then(role, typed);
    }

private:
    Then m_then;
};

inline bool kitAlert(QQmlEngine *engine, const QString &module, const QVariantMap &what, AlertAnswer::Then then = {})
{
    if (!engine)
        return false;
    QQmlComponent component(engine);
    component.loadFromModule(module, QStringLiteral("AlertWindow"));
    QObject *made = component.createWithInitialProperties(what);
    auto *window = qobject_cast<QQuickWindow *>(made);
    if (!window) {
        qWarning("kit: no alert (%s)", qPrintable(component.errorString()));
        delete made;
        return false;
    }
    QQmlEngine::setObjectOwnership(window, QQmlEngine::CppOwnership);
    QObject::connect(window, SIGNAL(answered(QString, QString)), new AlertAnswer(std::move(then), window), SLOT(take(QString, QString)));
    window->show();
    window->raise();
    window->requestActivate();
    return true;
}
