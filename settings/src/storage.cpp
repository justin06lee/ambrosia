#include "storage.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <QDir>
#include <QStandardPaths>
#include <QStorageInfo>
#include <QVariantMap>

using namespace Qt::StringLiterals;

namespace
{
QString bytesText(qint64 bytes)
{
    const double gb = bytes / 1e9;
    return gb >= 1 ? QStringLiteral("%1 GB").arg(gb, 0, 'f', 2)
                   : QStringLiteral("%1 MB").arg(bytes / 1e6, 0, 'f', 1);
}

struct Category {
    const char *name;
    QStringList paths;
};

QList<Category> categoriesToScan()
{
    const QString home = QDir::homePath();
    return {
        {QT_TR_NOOP("Applications"), {u"/usr"_s, u"/opt"_s}},
        {QT_TR_NOOP("Documents"), {home + u"/Desktop"_s, home + u"/Documents"_s, home + u"/Downloads"_s,
                                   home + u"/Pictures"_s, home + u"/Music"_s, home + u"/Videos"_s}},
        {QT_TR_NOOP("Trash"), {QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + u"/Trash"_s}},
    };
}

KConfigGroup trashSettings()
{
    const QString trash = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + u"/Trash"_s;
    return KSharedConfig::openConfig(u"ktrashrc"_s)->group(trash);
}
}

Storage::Storage(QObject *parent)
    : QObject(parent)
{
    connect(&m_du, &QProcess::finished, this, [this](int, QProcess::ExitStatus status) {
        if (status != QProcess::NormalExit || m_scanning < 0)
            return;
        // du's last line is the total, whatever it couldn't read.
        const QList<QByteArray> lines = m_du.readAllStandardOutput().trimmed().split('\n');
        m_sizes[m_scanning] = lines.isEmpty() ? 0 : lines.last().split('\t').first().toLongLong();
        Q_EMIT changed();
        next();
    });
}

void Storage::start()
{
    stop();
    m_sizes = QList<qint64>(categoriesToScan().size(), -1);
    m_scanning = -1;
    Q_EMIT changed();
    next();
}

void Storage::stop()
{
    m_scanning = -1;
    if (m_du.state() != QProcess::NotRunning) {
        m_du.kill();
        m_du.waitForFinished(1000);
    }
}

void Storage::next()
{
    const QList<Category> all = categoriesToScan();
    if (++m_scanning >= all.size()) {
        m_scanning = -1;
        return;
    }
    QStringList paths;
    for (const QString &path : all[m_scanning].paths) {
        if (QFileInfo::exists(path))
            paths.append(path);
    }
    if (paths.isEmpty()) {
        m_sizes[m_scanning] = 0;
        Q_EMIT changed();
        next();
        return;
    }
    m_du.start(u"ionice"_s, QStringList{u"-c3"_s, u"nice"_s, u"-n19"_s, u"du"_s, u"-xsbc"_s} + paths);
}

QString Storage::volume() const
{
    const QString name = QStorageInfo::root().name();
    return name.isEmpty() ? tr("System") : name;
}

qreal Storage::total() const
{
    return qreal(QStorageInfo::root().bytesTotal());
}

QString Storage::usedText() const
{
    const QStorageInfo root = QStorageInfo::root();
    return tr("%1 of %2 used").arg(bytesText(root.bytesTotal() - root.bytesAvailable()), bytesText(root.bytesTotal()));
}

QVariantList Storage::categories() const
{
    QVariantList list;
    const QList<Category> all = categoriesToScan();
    const QStorageInfo root = QStorageInfo::root();
    qint64 rest = root.bytesTotal() - root.bytesAvailable();
    bool known = !m_sizes.isEmpty();
    for (int i = 0; i < all.size(); ++i) {
        const qint64 bytes = m_sizes.value(i, -1);
        known = known && bytes >= 0;
        if (bytes > 0)
            rest -= bytes;
        list.append(QVariantMap{{u"name"_s, tr(all[i].name)}, {u"bytes"_s, qreal(bytes)}, {u"text"_s, bytes < 0 ? tr("Calculating…") : bytesText(bytes)}});
    }
    list.append(QVariantMap{{u"name"_s, tr("System Data")}, {u"bytes"_s, known ? qreal(qMax<qint64>(rest, 0)) : qreal(-1)},
                            {u"text"_s, known ? bytesText(qMax<qint64>(rest, 0)) : tr("Calculating…")}});
    return list;
}

bool Storage::emptyTrash() const
{
    return trashSettings().readEntry("UseTimeLimit", false);
}

void Storage::setEmptyTrash(bool on)
{
    KConfigGroup group = trashSettings();
    group.writeEntry("UseTimeLimit", on);
    group.writeEntry("Days", 30);
    group.sync();
    Q_EMIT changed();
}
