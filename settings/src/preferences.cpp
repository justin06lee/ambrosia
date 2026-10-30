#include "preferences.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>

namespace
{
KConfigGroup desktop()
{
    return KSharedConfig::openConfig(QStringLiteral("kdeglobals"))->group(QStringLiteral("KDE"));
}
}

Preferences::Preferences(QObject *parent)
    : QObject(parent)
    , m_path(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/ambrosia/settings.json"))
{
    QDir().mkpath(QFileInfo(m_path).path());
    // A write replaces the file, so its folder is watched too.
    m_watcher.addPath(QFileInfo(m_path).path());
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &Preferences::read);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &Preferences::read);
    read();
}

void Preferences::read()
{
    QFile file(m_path);
    if (!file.open(QIODevice::ReadOnly))
        return;
    m_watcher.addPath(m_path);
    const QJsonObject settings = QJsonDocument::fromJson(file.readAll()).object();
    if (settings.isEmpty() || settings == m_settings)
        return;
    m_settings = settings;
    Q_EMIT changed();
}

void Preferences::write()
{
    QSaveFile file(m_path);
    if (!file.open(QIODevice::WriteOnly)
        || file.write(QJsonDocument(m_settings).toJson()) < 0 || !file.commit())
        qWarning("Settings: couldn't write %s", qPrintable(m_path));
    Q_EMIT changed();
}

QString Preferences::appearance() const
{
    return m_settings.value(QStringLiteral("appearance")).toString(
        m_settings.value(QStringLiteral("dark")).toBool() ? QStringLiteral("dark") : QStringLiteral("light"));
}

void Preferences::setAppearance(const QString &appearance)
{
    read();
    m_settings.insert(QStringLiteral("appearance"), appearance);
    // Auto's light or dark is the shell's to say.
    if (appearance != QLatin1String("auto"))
        m_settings.insert(QStringLiteral("dark"), appearance == QLatin1String("dark"));
    write();
}

QString Preferences::accent() const
{
    return m_settings.value(QStringLiteral("accent")).toString(QStringLiteral("blue"));
}

void Preferences::setAccent(const QString &accent)
{
    read();
    m_settings.insert(QStringLiteral("accent"), accent);
    write();
}

bool Preferences::jumpToClick() const
{
    return !desktop().readEntry("ScrollbarLeftClickNavigatesByPage", true);
}

void Preferences::setJumpToClick(bool on)
{
    KConfigGroup group = desktop();
    group.writeEntry("ScrollbarLeftClickNavigatesByPage", !on, KConfig::Notify);
    group.sync();
    Q_EMIT changed();
}
