#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Login Items: what opens at login, the user's ~/.config/autostart, which the
// session starts. Services and timers aren't login items and aren't here.
class LoginItems : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{value (the file), text, icon}], sorted.
    Q_PROPERTY(QVariantList items READ items NOTIFY changed)
    // The same of every app there is, to add from.
    Q_PROPERTY(QVariantList apps READ apps CONSTANT)

public:
    explicit LoginItems(QObject *parent = nullptr);

    QVariantList items() const;
    QVariantList apps() const;

    Q_INVOKABLE void add(const QString &file);
    Q_INVOKABLE void remove(const QString &file);

Q_SIGNALS:
    void changed();
};
