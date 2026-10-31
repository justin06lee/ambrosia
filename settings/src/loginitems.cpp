#include "loginitems.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <QDir>
#include <QFile>
#include <QSet>
#include <QStandardPaths>
#include <QVariantMap>
#include <algorithm>

using namespace Qt::StringLiterals;

namespace
{
QString autostartFolder()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + u"/autostart"_s;
}

QVariantList entriesIn(const QStringList &folders)
{
    QVariantList list;
    QSet<QString> seen;
    for (const QString &folder : folders) {
        const QStringList files = QDir(folder).entryList({u"*.desktop"_s}, QDir::Files);
        for (const QString &file : files) {
            if (seen.contains(file))
                continue;
            seen.insert(file);
            const KConfigGroup entry = KSharedConfig::openConfig(folder + u'/' + file, KConfig::SimpleConfig)->group(u"Desktop Entry"_s);
            if (entry.readEntry("Hidden", false) || entry.readEntry("NoDisplay", false) || entry.readEntry("Type") != "Application"_L1)
                continue;
            list.append(QVariantMap{{u"value"_s, file}, {u"text"_s, entry.readEntry("Name", file)}, {u"icon"_s, entry.readEntry("Icon")}});
        }
    }
    std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(u"text"_s).toString().localeAwareCompare(b.toMap().value(u"text"_s).toString()) < 0;
    });
    return list;
}
}

LoginItems::LoginItems(QObject *parent)
    : QObject(parent)
{
}

QVariantList LoginItems::items() const
{
    return entriesIn({autostartFolder()});
}

QVariantList LoginItems::apps() const
{
    return entriesIn(QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation));
}

void LoginItems::add(const QString &file)
{
    QDir().mkpath(autostartFolder());
    const QString target = autostartFolder() + u'/' + file;
    const QString source = QStandardPaths::locate(QStandardPaths::ApplicationsLocation, file);
    if (source.isEmpty() || (!QFile::exists(target) && !QFile::copy(source, target)))
        qWarning("Settings: couldn't add %s to login items", qPrintable(file));
    Q_EMIT changed();
}

void LoginItems::remove(const QString &file)
{
    if (!QFile::remove(autostartFolder() + u'/' + file))
        qWarning("Settings: couldn't remove %s from login items", qPrintable(file));
    Q_EMIT changed();
}
