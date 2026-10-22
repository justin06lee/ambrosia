#include "places.h"
#include "tags.h"

#include <QDir>
#include <QStandardPaths>
#include <QSysInfo>
#include <QUrl>

namespace {

QVariantMap item(const QString &name, const QUrl &url, const QString &glyph)
{
    return {{QStringLiteral("name"), name}, {QStringLiteral("url"), url}, {QStringLiteral("glyph"), glyph}};
}

QVariantMap section(const QString &title, const QVariantList &items)
{
    return {{QStringLiteral("title"), title}, {QStringLiteral("items"), items}};
}

QUrl standard(QStandardPaths::StandardLocation location)
{
    return QUrl::fromLocalFile(QStandardPaths::writableLocation(location));
}

}

Places::Places(QObject *parent)
    : QObject(parent)
{
    connect(Tags::instance(), &Tags::listChanged, this, &Places::sectionsChanged);
}

QString Places::computer() const
{
    return QSysInfo::machineHostName();
}

QVariantList Places::sections() const
{
    const QString home = QDir::homePath();
    QVariantList favorites;
    favorites << item(QStringLiteral("Desktop"), standard(QStandardPaths::DesktopLocation), QStringLiteral("desktop"))
              << item(QStringLiteral("Documents"), standard(QStandardPaths::DocumentsLocation), QStringLiteral("documents"))
              << item(QStringLiteral("Downloads"), standard(QStandardPaths::DownloadLocation), QStringLiteral("downloads"));
    QVariantList locations;
    locations << item(QDir(home).dirName(), QUrl::fromLocalFile(home), QStringLiteral("home"))
              << item(computer(), QUrl::fromLocalFile(QStringLiteral("/")), QStringLiteral("drive"))
              << item(QStringLiteral("Trash"), QUrl(QStringLiteral("trash:/")), QStringLiteral("trash"));
    // A tag lists what has it: a search for it.
    QVariantList tags;
    for (const QVariant &tag : Tags::instance()->all()) {
        QVariantMap map = tag.toMap();
        QUrl url(QStringLiteral("search:"));
        url.setQuery(QStringLiteral("tag=") + QString::fromLatin1(QUrl::toPercentEncoding(map.value(QStringLiteral("name")).toString())));
        map.insert(QStringLiteral("url"), url);
        tags << map;
    }
    return {
        section(QString(), {item(QStringLiteral("Recents"), QUrl(QStringLiteral("recentlyused:/files")), QStringLiteral("recents"))}),
        section(QStringLiteral("Favorites"), favorites),
        section(QStringLiteral("Locations"), locations),
        section(QStringLiteral("Tags"), tags),
    };
}
