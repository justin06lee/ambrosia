#include "preferences.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <QColorDialog>
#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>
#include <QWindow>

namespace
{
KConfigGroup desktop()
{
    return KSharedConfig::openConfig(QStringLiteral("kdeglobals"))->group(QStringLiteral("KDE"));
}

// How many added pictures are offered again.
constexpr int recentPictures = 11;

// Over the window it was asked from, and gone when it closes.
void present(QDialog *dialog)
{
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    dialog->winId();
    if (QWindow *parent = QGuiApplication::focusWindow())
        dialog->windowHandle()->setTransientParent(parent);
    dialog->open();
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

QString Preferences::wallpaper() const
{
    const QString wallpaper = m_settings.value(QStringLiteral("wallpaper")).toString(QStringLiteral("nectar"));
    return wallpaper.startsWith(QLatin1Char('/')) && !QFile::exists(wallpaper) ? QStringLiteral("nectar") : wallpaper;
}

void Preferences::setWallpaper(const QString &wallpaper)
{
    read();
    m_settings.insert(QStringLiteral("wallpaper"), wallpaper);
    write();
}

QString Preferences::wallpaperFit() const
{
    return m_settings.value(QStringLiteral("wallpaperFit")).toString(QStringLiteral("fill"));
}

void Preferences::setWallpaperFit(const QString &fit)
{
    read();
    m_settings.insert(QStringLiteral("wallpaperFit"), fit);
    write();
}

QStringList Preferences::wallpaperRecent() const
{
    QStringList recent;
    const QJsonArray saved = m_settings.value(QStringLiteral("wallpaperRecent")).toArray();
    for (const QJsonValue &path : saved) {
        if (QFile::exists(path.toString()))
            recent.append(path.toString());
    }
    return recent;
}

QString Preferences::wallpaperFolder() const
{
    const QString folder = qEnvironmentVariable("AMBROSIA_WALLPAPERS");
    return folder.isEmpty() ? QStringLiteral("/usr/share/ambrosia/wallpapers") : folder;
}

QUrl Preferences::pictureUrl(const QString &path) const
{
    return QUrl::fromLocalFile(path);
}

void Preferences::addWallpaperPicture()
{
    auto *dialog = new QFileDialog(nullptr, tr("Add Photo"),
                                   QStandardPaths::writableLocation(QStandardPaths::PicturesLocation),
                                   tr("Pictures (*.png *.jpg *.jpeg *.webp *.avif *.heic *.bmp *.tif *.tiff)"));
    dialog->setFileMode(QFileDialog::ExistingFile);
    connect(dialog, &QFileDialog::fileSelected, this, [this](const QString &path) {
        read();
        QJsonArray recent{path};
        const QJsonArray saved = m_settings.value(QStringLiteral("wallpaperRecent")).toArray();
        for (const QJsonValue &other : saved) {
            if (other.toString() != path && recent.size() < recentPictures)
                recent.append(other);
        }
        m_settings.insert(QStringLiteral("wallpaperRecent"), recent);
        m_settings.insert(QStringLiteral("wallpaper"), path);
        write();
    });
    present(dialog);
}

void Preferences::chooseWallpaperColor()
{
    const QString now = wallpaper();
    auto *dialog = new QColorDialog(now.startsWith(QLatin1Char('#')) ? QColor(now) : QColor(Qt::black));
    dialog->setWindowTitle(tr("Custom Color"));
    connect(dialog, &QColorDialog::colorSelected, this, [this](const QColor &color) {
        setWallpaper(color.name());
    });
    present(dialog);
}

QVariantMap Preferences::all() const
{
    return m_settings.toVariantMap();
}

void Preferences::set(const QString &key, const QVariant &value)
{
    read();
    m_settings.insert(key, QJsonValue::fromVariant(value));
    write();
}

int Preferences::dockSize() const
{
    return m_settings.value(QStringLiteral("dockSize")).toInt(52);
}

void Preferences::setDockSize(int size)
{
    set(QStringLiteral("dockSize"), size);
}

qreal Preferences::dockMagnification() const
{
    return m_settings.value(QStringLiteral("dockMagnification")).toDouble(0);
}

void Preferences::setDockMagnification(qreal amount)
{
    set(QStringLiteral("dockMagnification"), amount);
}

QString Preferences::dockPosition() const
{
    return m_settings.value(QStringLiteral("dockPosition")).toString(QStringLiteral("bottom"));
}

void Preferences::setDockPosition(const QString &position)
{
    set(QStringLiteral("dockPosition"), position);
}

bool Preferences::dockAutohide() const
{
    return m_settings.value(QStringLiteral("dockAutohide")).toBool(false);
}

void Preferences::setDockAutohide(bool on)
{
    set(QStringLiteral("dockAutohide"), on);
}

bool Preferences::dockBounce() const
{
    return m_settings.value(QStringLiteral("dockBounce")).toBool(true);
}

void Preferences::setDockBounce(bool on)
{
    set(QStringLiteral("dockBounce"), on);
}

bool Preferences::dockIndicators() const
{
    return m_settings.value(QStringLiteral("dockIndicators")).toBool(true);
}

void Preferences::setDockIndicators(bool on)
{
    set(QStringLiteral("dockIndicators"), on);
}
