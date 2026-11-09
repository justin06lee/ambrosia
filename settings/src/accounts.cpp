#include "accounts.h"

#include "dryrun.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusReply>
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSocketNotifier>
#include <QTimer>
#include <QUrl>

#include <algorithm>
#include <crypt.h>
#include <csignal>
#include <memory>
#include <pty.h>
#include <pwd.h>
#include <sys/wait.h>
#include <unistd.h>

using namespace Qt::StringLiterals;

namespace
{
const auto accounts = u"org.freedesktop.Accounts"_s;
const auto accountsPath = u"/org/freedesktop/Accounts"_s;
const auto userInterface = u"org.freedesktop.Accounts.User"_s;

// A password as /etc/shadow keeps it, in the system's default hash (yescrypt).
QString hashed(const QString &password)
{
    char salt[CRYPT_GENSALT_OUTPUT_SIZE];
    if (!crypt_gensalt_rn(nullptr, 0, nullptr, 0, salt, sizeof salt))
        return {};
    auto data = std::make_unique<crypt_data>();
    const char *hash = crypt_r(password.toUtf8().constData(), salt, data.get());
    if (!hash || hash[0] == '*')
        return {};
    return QString::fromLatin1(hash);
}
}

Accounts::Accounts(QObject *parent)
    : QObject(parent)
{
    QDBusConnection bus = QDBusConnection::systemBus();
    bus.connect(accounts, accountsPath, accounts, u"UserAdded"_s, this, SLOT(read()));
    bus.connect(accounts, accountsPath, accounts, u"UserDeleted"_s, this, SLOT(read()));
    bus.connect(accounts, QString(), userInterface, u"Changed"_s, this, SLOT(read()));
    read();
    m_ready = true;
}

Accounts::~Accounts()
{
    if (m_child > 0) {
        ::kill(m_child, SIGKILL);
        ::waitpid(m_child, nullptr, 0);
    }
    if (m_pty >= 0)
        ::close(m_pty);
}

void Accounts::read()
{
    QDBusInterface manager(accounts, accountsPath, accounts, QDBusConnection::systemBus());
    const QDBusReply<QList<QDBusObjectPath>> paths = manager.call(u"ListCachedUsers"_s);
    QVariantList mine, others;
    const qlonglong me = ::getuid();
    if (paths.isValid()) {
        for (const QDBusObjectPath &path : paths.value()) {
            QDBusInterface user(accounts, path.path(), userInterface, QDBusConnection::systemBus());
            if (user.property("SystemAccount").toBool())
                continue;
            const qlonglong uid = user.property("Uid").toLongLong();
            const QString icon = user.property("IconFile").toString();
            QVariantMap entry{
                {u"path"_s, path.path()},
                {u"uid"_s, uid},
                {u"name"_s, user.property("UserName").toString()},
                {u"fullName"_s, user.property("RealName").toString()},
                {u"icon"_s, !icon.isEmpty() && QFileInfo(icon).isReadable() && QFileInfo(icon).size() > 0 ? QUrl::fromLocalFile(icon).toString() : QString()},
                {u"admin"_s, user.property("AccountType").toInt() == 1},
                {u"me"_s, uid == me},
            };
            if (uid == me) {
                m_passwordSet = user.property("PasswordMode").toInt() != 2;
                mine.append(entry);
            } else {
                others.append(entry);
            }
        }
    }
    m_users = mine + others;
    if (m_ready)
        Q_EMIT changed();
}

int Accounts::admins() const
{
    return std::count_if(m_users.cbegin(), m_users.cend(), [](const QVariant &user) {
        return user.toMap().value(u"admin"_s).toBool();
    });
}

QStringList Accounts::pictures() const
{
    QStringList list;
    const QDir folder(u"/usr/share/plasma/avatars"_s);
    for (const QFileInfo &file : folder.entryInfoList({u"*.png"_s, u"*.jpg"_s}, QDir::Files, QDir::Name))
        list.append(QUrl::fromLocalFile(file.absoluteFilePath()).toString());
    return list;
}

QString Accounts::suggestName(const QString &fullName) const
{
    QString name = fullName.normalized(QString::NormalizationForm_KD).toLower();
    name.remove(QRegularExpression(u"[^a-z0-9_-]"_s));
    while (!name.isEmpty() && !name.front().isLetter() && name.front() != u'_')
        name.remove(0, 1);
    return name.left(32);
}

QString Accounts::nameProblem(const QString &name) const
{
    if (name.isEmpty())
        return {};
    if (!QRegularExpression(u"^[a-z_][a-z0-9_-]{0,31}$"_s).match(name).hasMatch())
        return tr("Use lowercase letters, digits, - and _, starting with a letter.");
    for (const QVariant &user : m_users)
        if (user.toMap().value(u"name"_s).toString() == name)
            return tr("This name is already used.");
    if (::getpwnam(name.toLatin1().constData()))
        return tr("This name is already used by the system.");
    return {};
}

// The user's own call, answered through polkit where it asks.
void Accounts::call(const QString &path, const QString &method, const QVariantList &arguments, const char *what)
{
    if (dryRun(what))
        return;
    QDBusMessage message = QDBusMessage::createMethodCall(accounts, path, path == accountsPath ? accounts : userInterface, method);
    message.setArguments(arguments);
    message.setInteractiveAuthorizationAllowed(true);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message, 120000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        watcher->deleteLater();
        if (watcher->isError())
            qWarning("Settings: AccountsService: %s", qPrintable(watcher->error().message()));
        read();
    });
}

void Accounts::setAdmin(const QString &path, bool admin)
{
    call(path, u"SetAccountType"_s, {admin ? 1 : 0}, admin ? "make a user an administrator" : "make a user standard");
}

void Accounts::setFullName(const QString &path, const QString &name)
{
    if (!name.trimmed().isEmpty())
        call(path, u"SetRealName"_s, {name.trimmed()}, "set a user's full name");
}

void Accounts::setPicture(const QString &path, const QString &file)
{
    const QString local = QUrl(file).isLocalFile() ? QUrl(file).toLocalFile() : file;
    call(path, u"SetIconFile"_s, {local}, "set a user's picture");
}

void Accounts::deleteUser(qlonglong uid, bool removeHome)
{
    if (uid == ::getuid())
        return;
    call(accountsPath, u"DeleteUser"_s, {uid, removeHome}, removeHome ? "delete a user and their home folder" : "delete a user, keeping their home folder");
}

// The account, then its password: both asked for once, polkit keeping the
// answer between them.
void Accounts::createUser(const QString &fullName, const QString &name, const QString &password, bool admin)
{
    const QString hash = hashed(password);
    if (hash.isEmpty()) {
        Q_EMIT createDone(false, tr("The password couldn't be stored."));
        return;
    }
    if (dryRun(qPrintable(u"add the user "_s + name + (admin ? u" (administrator)"_s : u" (standard)"_s)))) {
        Q_EMIT createDone(true, {});
        return;
    }
    QDBusMessage message = QDBusMessage::createMethodCall(accounts, accountsPath, accounts, u"CreateUser"_s);
    message.setArguments({name, fullName, admin ? 1 : 0});
    message.setInteractiveAuthorizationAllowed(true);
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(message, 120000), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, hash] {
        watcher->deleteLater();
        const QDBusReply<QDBusObjectPath> reply = *watcher;
        if (!reply.isValid()) {
            qWarning("Settings: AccountsService: %s", qPrintable(reply.error().message()));
            Q_EMIT createDone(false, reply.error().type() == QDBusError::AccessDenied ? QString() : reply.error().message());
            read();
            return;
        }
        QDBusMessage password = QDBusMessage::createMethodCall(accounts, reply.value().path(), userInterface, u"SetPassword"_s);
        password.setArguments({hash, QString()});
        password.setInteractiveAuthorizationAllowed(true);
        auto *second = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(password, 120000), this);
        connect(second, &QDBusPendingCallWatcher::finished, this, [this, second] {
            second->deleteLater();
            if (second->isError()) {
                qWarning("Settings: AccountsService: %s", qPrintable(second->error().message()));
                Q_EMIT createDone(false, tr("The user was added, but their password couldn't be set."));
            } else {
                Q_EMIT createDone(true, {});
            }
            read();
        });
    });
}

// passwd on a terminal of its own, in plain English so its prompts can be
// told apart: the old password when it asks for the current one, the new
// one twice. A second "New password" means it didn't take the first (too
// short, say, where a rule says so): it's stopped and its reason shown.
void Accounts::changePassword(const QString &oldPassword, const QString &newPassword)
{
    if (m_child > 0)
        return;
    if (dryRun("change your login password (passwd)")) {
        Q_EMIT passwordDone(true, {});
        return;
    }
    int pty = -1;
    const pid_t child = ::forkpty(&pty, nullptr, nullptr, nullptr);
    if (child < 0) {
        Q_EMIT passwordDone(false, tr("The password couldn't be changed."));
        return;
    }
    if (child == 0) {
        ::setenv("LC_ALL", "C", 1);
        ::setenv("LANG", "C", 1);
        ::execlp("passwd", "passwd", static_cast<char *>(nullptr));
        ::_exit(127);
    }
    m_child = child;
    m_pty = pty;
    m_output.clear();
    m_old = oldPassword.toUtf8();
    m_new = newPassword.toUtf8();
    m_asked = 0;
    m_sawNew = false;
    m_newPrompts = 0;
    m_notifier = new QSocketNotifier(pty, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &Accounts::ptyReady);
    m_deadline = new QTimer(this);
    m_deadline->setSingleShot(true);
    connect(m_deadline, &QTimer::timeout, this, [this] {
        finishPassword(true);
    });
    m_deadline->start(30000);
    Q_EMIT changingPasswordChanged();
}

void Accounts::ptyReady()
{
    char buffer[512];
    const ssize_t got = ::read(m_pty, buffer, sizeof buffer);
    if (got <= 0) {
        finishPassword(false);
        return;
    }
    m_output.append(buffer, got);
    const QByteArray fresh = m_output.mid(m_asked).trimmed().toLower();
    auto answer = [this](const QByteArray &text) {
        const QByteArray line = text + '\n';
        if (::write(m_pty, line.constData(), line.size()) < 0)
            qWarning("Settings: passwd: couldn't answer");
        m_asked = m_output.size();
    };
    if (fresh.endsWith("retype new password:")) {
        answer(m_new);
    } else if (fresh.endsWith("new password:")) {
        if (++m_newPrompts > 1) {
            finishPassword(true);
            return;
        }
        m_sawNew = true;
        answer(m_new);
    } else if (fresh.endsWith("password:")) {
        answer(m_old);
    }
}

void Accounts::finishPassword(bool killed)
{
    if (m_child <= 0)
        return;
    if (killed)
        ::kill(m_child, SIGKILL);
    int status = 0;
    ::waitpid(m_child, &status, 0);
    m_child = 0;
    delete m_notifier;
    m_notifier = nullptr;
    delete m_deadline;
    m_deadline = nullptr;
    ::close(m_pty);
    m_pty = -1;
    m_old.fill('\0');
    m_new.fill('\0');
    m_old.clear();
    m_new.clear();
    Q_EMIT changingPasswordChanged();

    const bool ok = !killed && WIFEXITED(status) && WEXITSTATUS(status) == 0;
    if (ok) {
        Q_EMIT passwordDone(true, {});
        read();
        return;
    }
    if (!m_sawNew) {
        Q_EMIT passwordDone(false, u"old"_s);
        return;
    }
    // What passwd said that wasn't a prompt: its reason.
    QStringList said;
    for (const QByteArray &raw : m_output.split('\n')) {
        const QString line = QString::fromUtf8(raw).trimmed();
        const QString lower = line.toLower();
        if (line.isEmpty() || lower.endsWith(u"password:"_s) || lower.startsWith(u"changing password"_s) || lower.contains(u"password unchanged"_s))
            continue;
        said.append(line.startsWith(u"passwd: "_s) ? line.mid(8) : line);
    }
    m_output.clear();
    Q_EMIT passwordDone(false, said.isEmpty() ? tr("The password couldn't be changed.") : said.join(u' '));
}
