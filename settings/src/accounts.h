#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QSocketNotifier;
class QTimer;

// Users & Groups and Login Password: the people with an account here
// (AccountsService, which asks through polkit), and changing your own
// password through passwd, so PAM checks the old one and its rules apply.
class Accounts : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{path, uid, name, fullName, icon (a file URL or ""), admin, me}], you first.
    Q_PROPERTY(QVariantList users READ users NOTIFY changed)
    Q_PROPERTY(bool passwordSet READ passwordSet NOTIFY changed)
    // An admin besides you: you can only stop being one if so.
    Q_PROPERTY(int admins READ admins NOTIFY changed)
    Q_PROPERTY(QStringList pictures READ pictures CONSTANT)
    Q_PROPERTY(bool changingPassword READ changingPassword NOTIFY changingPasswordChanged)

public:
    explicit Accounts(QObject *parent = nullptr);
    ~Accounts() override;

    QVariantList users() const { return m_users; }
    bool passwordSet() const { return m_passwordSet; }
    int admins() const;
    QStringList pictures() const;
    bool changingPassword() const { return m_child > 0; }

    // Your password: done(true, "") or done(false, why), "old" when the old
    // one was wrong.
    Q_INVOKABLE void changePassword(const QString &oldPassword, const QString &newPassword);
    Q_INVOKABLE void createUser(const QString &fullName, const QString &name, const QString &password, bool admin);
    Q_INVOKABLE void deleteUser(qlonglong uid, bool removeHome);
    Q_INVOKABLE void setAdmin(const QString &path, bool admin);
    Q_INVOKABLE void setFullName(const QString &path, const QString &name);
    Q_INVOKABLE void setPicture(const QString &path, const QString &file);
    // The short name a full name suggests, as the Mac makes one.
    Q_INVOKABLE QString suggestName(const QString &fullName) const;
    // Why a short name can't be used, or "".
    Q_INVOKABLE QString nameProblem(const QString &name) const;

public Q_SLOTS:
    void read();

Q_SIGNALS:
    void changed();
    void changingPasswordChanged();
    void passwordDone(bool ok, const QString &message);
    // A user added or not (message why not).
    void createDone(bool ok, const QString &message);

private:
    // Set once constructed: a change read while QML is still creating us
    // (Panes asking Power for the battery) mustn't loop back into it.
    bool m_ready = false;
    void ptyReady();
    void finishPassword(bool killed);
    void call(const QString &path, const QString &method, const QVariantList &arguments, const char *what);

    QVariantList m_users;
    bool m_passwordSet = true;
    // The passwd being answered: its pid, its terminal, what it has said.
    int m_child = 0;
    int m_pty = -1;
    QSocketNotifier *m_notifier = nullptr;
    QTimer *m_deadline = nullptr;
    QByteArray m_output;
    QByteArray m_old, m_new;
    int m_asked = 0;
    bool m_sawNew = false;
    int m_newPrompts = 0;
};
