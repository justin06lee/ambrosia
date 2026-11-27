#include "store.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJSEngine>
#include <QSaveFile>
#include <QStandardPaths>

namespace
{
const QString home = QStringLiteral("Notes");
const QString deleted = QStringLiteral(".deleted");
const QString suffix = QStringLiteral(".md");
// A note larger than this is not one of ours.
const qint64 largest = 8 * 1024 * 1024;

// A name that stays inside the directory it is put in.
bool plain(const QString &name)
{
    return !name.isEmpty() && !name.contains(QLatin1Char('/')) && !name.contains(QChar(0)) && name != QLatin1String(".") && name != QLatin1String("..");
}

bool folderName(const QString &name)
{
    return plain(name) && (name == deleted || !name.startsWith(QLatin1Char('.')));
}
}

Store *Store::s_instance = nullptr;

Store::Store(const QString &root)
    : m_root(root.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/ambrosia/notes") : root)
{
    s_instance = this;
    QJSEngine::setObjectOwnership(this, QJSEngine::CppOwnership);
    if (!QDir().mkpath(m_root + QLatin1Char('/') + home))
        qWarning("Notes: no place to keep notes at %s", qPrintable(m_root));
}

Store *Store::create(QQmlEngine *, QJSEngine *)
{
    return s_instance;
}

QString Store::dir(const QString &folder) const
{
    return folderName(folder) ? m_root + QLatin1Char('/') + folder : QString();
}

QString Store::file(const QString &folder, const QString &id) const
{
    const QString in = dir(folder);
    return in.isEmpty() || !plain(id) || id.startsWith(QLatin1Char('.')) ? QString() : in + QLatin1Char('/') + id + suffix;
}

QStringList Store::folders() const
{
    QStringList names;
    const QStringList found = QDir(m_root).entryList(QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden, QDir::Name);
    for (const QString &name : found) {
        if (folderName(name))
            names << name;
    }
    return names;
}

QVariantList Store::read() const
{
    QVariantList notes;
    const QStringList names = folders();
    for (const QString &folder : names) {
        const QFileInfoList files = QDir(dir(folder)).entryInfoList({QLatin1Char('*') + suffix}, QDir::Files | QDir::Readable, QDir::Name);
        for (const QFileInfo &info : files) {
            if (info.size() > largest || info.fileName().startsWith(QLatin1Char('.')))
                continue;
            QFile source(info.absoluteFilePath());
            if (!source.open(QIODevice::ReadOnly))
                continue;
            notes.append(QVariantMap{
                {QStringLiteral("folder"), folder},
                {QStringLiteral("id"), info.completeBaseName()},
                {QStringLiteral("text"), QString::fromUtf8(source.readAll())},
                {QStringLiteral("stamp"), info.lastModified().toMSecsSinceEpoch()},
            });
        }
    }
    return notes;
}

QVariantMap Store::one(const QString &folder, const QString &id) const
{
    const QString path = file(folder, id);
    QFile source(path);
    if (path.isEmpty() || !source.open(QIODevice::ReadOnly))
        return {};
    return {
        {QStringLiteral("text"), QString::fromUtf8(source.readAll())},
        {QStringLiteral("stamp"), QFileInfo(path).lastModified().toMSecsSinceEpoch()},
    };
}

bool Store::write(const QString &folder, const QString &id, const QString &text)
{
    const QString path = file(folder, id);
    if (path.isEmpty() || !QDir().mkpath(dir(folder)))
        return false;
    // Whole or not at all: a note is never left half written.
    QSaveFile target(path);
    if (!target.open(QIODevice::WriteOnly))
        return false;
    target.write(text.toUtf8());
    return target.commit();
}

bool Store::move(const QString &id, const QString &from, const QString &to)
{
    const QString source = file(from, id), target = file(to, id);
    if (source.isEmpty() || target.isEmpty() || !QFile::exists(source) || QFile::exists(target) || !QDir().mkpath(dir(to)))
        return false;
    return QFile::rename(source, target);
}

bool Store::remove(const QString &folder, const QString &id)
{
    const QString path = file(folder, id);
    return !path.isEmpty() && (!QFile::exists(path) || QFile::remove(path));
}

bool Store::createFolder(const QString &name)
{
    const QString path = dir(name);
    return !path.isEmpty() && !QFileInfo::exists(path) && QDir().mkdir(path);
}

bool Store::renameFolder(const QString &from, const QString &to)
{
    const QString source = dir(from), target = dir(to);
    if (source.isEmpty() || target.isEmpty() || from == home || from == deleted || to == deleted || QFileInfo::exists(target))
        return false;
    return QDir().rename(source, target);
}

bool Store::removeFolder(const QString &name)
{
    const QString path = dir(name);
    if (path.isEmpty() || name == home)
        return false;
    // rmdir: it goes only if nothing is in it.
    return QDir().rmdir(path);
}
