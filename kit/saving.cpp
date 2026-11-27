#include "saving.h"

#include "shadow.h"

#include <KWindowShadow>

#include <QDir>
#include <QFileDialog>
#include <QFileInfo>
#include <QGuiApplication>
#include <QStandardPaths>

Places::Places(QObject *parent)
    : QObject(parent)
{
}

QVariantList Places::list() const
{
    QVariantList places;
    QStringList seen;
    for (const auto where : {QStandardPaths::DesktopLocation, QStandardPaths::DocumentsLocation, QStandardPaths::DownloadLocation, QStandardPaths::HomeLocation}) {
        const QString path = QStandardPaths::writableLocation(where);
        if (path.isEmpty() || seen.contains(path) || !QFileInfo(path).isDir())
            continue;
        seen << path;
        places << QVariantMap{{QStringLiteral("name"), name(path)}, {QStringLiteral("path"), path}};
    }
    return places;
}

QString Places::documents() const
{
    const QString path = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    return QFileInfo(path).isDir() ? path : QDir::homePath();
}

QString Places::desktop() const
{
    const QString path = QStandardPaths::writableLocation(QStandardPaths::DesktopLocation);
    return QFileInfo(path).isDir() ? path : QString();
}

QString Places::name(const QString &folder) const
{
    const QString clean = QDir::cleanPath(folder);
    if (clean == QLatin1String("/"))
        return QStringLiteral("Computer");
    return QFileInfo(clean).fileName();
}

bool Places::exists(const QString &path) const
{
    return QFileInfo::exists(path);
}

bool Places::isFolder(const QString &path) const
{
    return QFileInfo(path).isDir();
}

QUrl Places::url(const QString &path) const
{
    return QUrl::fromLocalFile(path);
}

void Places::browse(int id, const QString &folder, const QString &name, const QString &filter)
{
    auto *dialog = new QFileDialog(nullptr, QStringLiteral("Save"));
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    dialog->setFileMode(QFileDialog::AnyFile);
    dialog->setAcceptMode(QFileDialog::AcceptSave);
    if (!filter.isEmpty())
        dialog->setNameFilter(filter);
    if (!folder.isEmpty())
        dialog->setDirectory(folder);
    dialog->selectFile(name);
    connect(dialog, &QFileDialog::finished, this, [this, dialog, id](int result) {
        const QList<QUrl> urls = result == QDialog::Accepted ? dialog->selectedUrls() : QList<QUrl>();
        Q_EMIT browsed(id, !urls.isEmpty() && urls.constFirst().isLocalFile() ? urls.constFirst().toLocalFile() : QString());
    });
    dialog->open();
}

void Places::shade(QQuickWindow *window, int radius)
{
    if (!window || QGuiApplication::platformName() == QLatin1String("offscreen"))
        return;
    if (!makeShadow(window, radius, window->devicePixelRatio())->create())
        qWarning("Save panel: KWin took no shadow for the window");
}
