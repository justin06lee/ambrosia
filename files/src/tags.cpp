#include "tags.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlEngine>
#include <QSaveFile>
#include <QStandardPaths>

#include <algorithm>
#include <cerrno>
#include <cstring>

#include <sys/xattr.h>

namespace {

const char key[] = "user.xdg.tags";

QString storePath()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/ambrosia/files/tags.json");
}

}

Tags *Tags::instance()
{
    static Tags *tags = new Tags;
    return tags;
}

Tags *Tags::create(QQmlEngine *, QJSEngine *)
{
    QJSEngine::setObjectOwnership(instance(), QJSEngine::CppOwnership);
    return instance();
}

Tags::Tags(QObject *parent)
    : QObject(parent)
{
    load();
}

void Tags::load()
{
    // Finder's own, always there and in its order.
    m_tags = {{QStringLiteral("Red"), QStringLiteral("red")},       {QStringLiteral("Orange"), QStringLiteral("orange")},
              {QStringLiteral("Yellow"), QStringLiteral("yellow")}, {QStringLiteral("Green"), QStringLiteral("green")},
              {QStringLiteral("Blue"), QStringLiteral("blue")},     {QStringLiteral("Purple"), QStringLiteral("purple")},
              {QStringLiteral("Gray"), QStringLiteral("gray")}};
    QFile file(storePath());
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonArray list = QJsonDocument::fromJson(file.readAll()).object().value(QStringLiteral("tags")).toArray();
    if (list.isEmpty())
        return;
    m_tags.clear();
    for (const QJsonValue &value : list) {
        const QJsonObject tag = value.toObject();
        const QString name = tag.value(QStringLiteral("name")).toString().trimmed();
        if (!name.isEmpty())
            m_tags.append({name, tag.value(QStringLiteral("color")).toString()});
    }
}

void Tags::save() const
{
    QJsonArray list;
    for (const Tag &tag : m_tags)
        list.append(QJsonObject{{QStringLiteral("name"), tag.name}, {QStringLiteral("color"), tag.color}});
    QDir().mkpath(QFileInfo(storePath()).absolutePath());
    QSaveFile file(storePath());
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(QJsonObject{{QStringLiteral("tags"), list}}).toJson());
        file.commit();
    }
}

QVariantList Tags::all() const
{
    QVariantList list;
    for (const Tag &tag : m_tags)
        list << QVariantMap{{QStringLiteral("name"), tag.name}, {QStringLiteral("color"), tag.color}};
    return list;
}

QStringList Tags::read(const QString &path)
{
    char value[4096];
    const ssize_t got = getxattr(QFile::encodeName(path).constData(), key, value, sizeof value);
    if (got <= 0)
        return {};
    QStringList names;
    for (const QString &name : QString::fromUtf8(value, got).split(QLatin1Char(','), Qt::SkipEmptyParts))
        if (const QString trimmed = name.trimmed(); !trimmed.isEmpty() && !names.contains(trimmed))
            names << trimmed;
    return names;
}

QString Tags::colorOf(const QString &name) const
{
    for (const Tag &tag : m_tags)
        if (tag.name.compare(name, Qt::CaseInsensitive) == 0)
            return tag.color;
    return {};
}

QStringList Tags::colorsOf(const QStringList &names) const
{
    QStringList colors;
    for (const QString &name : names)
        if (const QString color = colorOf(name); !color.isEmpty())
            colors << color;
    return colors;
}

QStringList Tags::of(const QUrl &url) const
{
    return url.isLocalFile() ? read(url.toLocalFile()) : QStringList();
}

QStringList Tags::common(const QList<QUrl> &urls) const
{
    if (urls.isEmpty())
        return {};
    QStringList names = of(urls.first());
    for (qsizetype i = 1; i < urls.size() && !names.isEmpty(); ++i) {
        const QStringList other = of(urls[i]);
        names.removeIf([&](const QString &name) { return !other.contains(name); });
    }
    return names;
}

void Tags::toggle(const QList<QUrl> &urls, const QString &name)
{
    edit(urls, name, !common(urls).contains(name));
}

void Tags::add(const QList<QUrl> &urls, const QString &name)
{
    edit(urls, name, true);
}

void Tags::remove(const QList<QUrl> &urls, const QString &name)
{
    edit(urls, name, false);
}

void Tags::edit(const QList<QUrl> &urls, const QString &given, bool on)
{
    // A comma would split the name in two where Dolphin reads it.
    QString name = given.trimmed();
    name.replace(QLatin1Char(','), QLatin1Char(' '));
    if (name.isEmpty())
        return;
    // A tag known by another case keeps its own name.
    for (const Tag &tag : std::as_const(m_tags))
        if (tag.name.compare(name, Qt::CaseInsensitive) == 0)
            name = tag.name;
    QList<QUrl> done;
    for (const QUrl &url : urls) {
        if (!url.isLocalFile())
            continue;
        const QByteArray path = QFile::encodeName(url.toLocalFile());
        QStringList names = read(url.toLocalFile());
        if (names.contains(name) == on)
            continue;
        if (on)
            names << name; // a new tag goes last, and shows first
        else
            names.removeAll(name);
        const QByteArray value = names.join(QLatin1Char(',')).toUtf8();
        const int result = value.isEmpty() ? removexattr(path.constData(), key)
                                           : setxattr(path.constData(), key, value.constData(), value.size(), 0);
        if (result != 0) {
            qWarning("Files: couldn't tag %s: %s", path.constData(), strerror(errno));
            continue;
        }
        done << url;
    }
    if (on && colorOf(name).isEmpty() && std::none_of(m_tags.begin(), m_tags.end(), [&](const Tag &t) { return t.name == name; })) {
        m_tags.append({name, QString()});
        save();
        Q_EMIT listChanged();
    }
    if (!done.isEmpty())
        Q_EMIT changed(done);
}
