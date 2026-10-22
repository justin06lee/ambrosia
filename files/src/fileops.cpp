#include "fileops.h"

#include <KIO/AskUserActionInterface>
#include <KIO/CopyJob>
#include <KIO/FileUndoManager>
#include <KIO/JobUiDelegateFactory>
#include <KIO/MkdirJob>
#include <KIO/Paste>
#include <KIO/RestoreJob>
#include <KJobUiDelegate>

#include <QClipboard>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QMessageBox>
#include <QMimeData>
#include <QRegularExpression>

#include <algorithm>

#include <sys/stat.h>

using KIO::FileUndoManager;

namespace {

// KIO asks before undoing anything that deletes, and New Folder's undo
// takes away a folder that is empty (or it fails): that one goes without
// asking, as in Finder. Undoing a copy still asks, since it deletes the copy.
class UndoUi : public FileUndoManager::UiInterface
{
public:
    bool ask = true;
    void virtual_hook(int id, void *data) override
    {
        if (id == HookGetAskUserActionInterface && !ask) {
            *static_cast<KIO::AskUserActionInterface **>(data) = nullptr;
            return;
        }
        UiInterface::virtual_hook(id, data);
    }
};
UndoUi *undoUi = nullptr;

QUrl childUrl(const QUrl &dir, const QString &name)
{
    QUrl url = dir;
    const QString path = url.path();
    url.setPath(path + (path.endsWith(QLatin1Char('/')) ? QString() : QStringLiteral("/")) + name);
    return url;
}

QUrl parentUrl(const QUrl &url)
{
    return url.adjusted(QUrl::RemoveFilename | QUrl::StripTrailingSlash);
}

bool sameUrl(const QUrl &a, const QUrl &b)
{
    return a.adjusted(QUrl::StripTrailingSlash | QUrl::NormalizePathSegments) == b.adjusted(QUrl::StripTrailingSlash | QUrl::NormalizePathSegments);
}

bool exists(const QUrl &url)
{
    return url.isLocalFile() && QFileInfo::exists(url.toLocalFile());
}

// Finder's name for a copy beside its original: "notes copy.md", then
// "notes copy 2.md"; a copy of a copy counts on from it.
QString copyName(const QUrl &url)
{
    const QString name = url.fileName();
    QString base = name, ext;
    if (!QFileInfo(url.toLocalFile()).isDir()) {
        const int dot = name.lastIndexOf(QLatin1Char('.'));
        if (dot > 0) {
            base = name.left(dot);
            ext = name.mid(dot);
        }
    }
    static const QRegularExpression copied(QStringLiteral(" copy( \\d+)?$"));
    base.remove(copied);
    const QUrl dir = parentUrl(url);
    for (int n = 1;; ++n) {
        const QString candidate = base + (n == 1 ? QStringLiteral(" copy") : QStringLiteral(" copy %1").arg(n)) + ext;
        if (!exists(childUrl(dir, candidate)))
            return candidate;
    }
}

// "“notes.md”" for one item, "3 Items" for more, as Finder's menus say.
QString itemsText(const QList<QUrl> &urls)
{
    if (urls.size() == 1)
        return QStringLiteral("“%1”").arg(urls.first().fileName());
    return QStringLiteral("%1 Items").arg(urls.size());
}

// What KIO calls a command, in Finder's words, when it isn't one of ours.
QString finderWords(QString kioText)
{
    kioText.remove(QLatin1Char('&'));
    const QString what = kioText.section(QStringLiteral(": "), 1);
    static const QHash<QString, QString> words{
        {QStringLiteral("Copy"), QStringLiteral("Copy")},
        {QStringLiteral("Link"), QStringLiteral("Make Alias")},
        {QStringLiteral("Move"), QStringLiteral("Move")},
        {QStringLiteral("Rename"), QStringLiteral("Rename")},
        {QStringLiteral("Trash"), QStringLiteral("Move to Trash")},
        {QStringLiteral("Create Folder"), QStringLiteral("New Folder")},
        {QStringLiteral("Create File"), QStringLiteral("Paste")},
        {QStringLiteral("Batch Rename"), QStringLiteral("Rename")},
    };
    return words.value(what, what);
}

}

FileOps::FileOps(QObject *parent)
    : QObject(parent)
{
    FileUndoManager *undo = FileUndoManager::self();
    if (!undoUi) {
        undoUi = new UndoUi;
        undo->setUiInterface(undoUi);
    }
    connect(undo, &FileUndoManager::undoAvailable, this, &FileOps::undoChanged);
    connect(undo, &FileUndoManager::undoTextChanged, this, &FileOps::undoChanged);
    connect(undo, &FileUndoManager::redoAvailable, this, &FileOps::undoChanged);
    connect(undo, &FileUndoManager::redoTextChanged, this, &FileOps::undoChanged);
    connect(undo, &FileUndoManager::undoJobFinished, this, [] { undoUi->ask = true; });
    connect(QGuiApplication::clipboard(), &QClipboard::dataChanged, this, &FileOps::clipboardChanged);
}

bool FileOps::canUndo() const
{
    return FileUndoManager::self()->isUndoAvailable();
}

QString FileOps::undoText() const
{
    FileUndoManager *undo = FileUndoManager::self();
    if (!undo->isUndoAvailable())
        return QStringLiteral("Undo");
    return QStringLiteral("Undo ") + m_labels.value(undo->currentCommandSerialNumber(), finderWords(undo->undoText()));
}

bool FileOps::canRedo() const
{
    return FileUndoManager::self()->isRedoAvailable();
}

QString FileOps::redoText() const
{
    FileUndoManager *undo = FileUndoManager::self();
    return undo->isRedoAvailable() ? QStringLiteral("Redo ") + finderWords(undo->redoText()) : QStringLiteral("Redo");
}

int FileOps::clipboardCount() const
{
    const QMimeData *mime = QGuiApplication::clipboard()->mimeData();
    return mime && mime->hasUrls() ? int(mime->urls().size()) : 0;
}

int FileOps::start(KJob *job, const QList<QUrl> &results, const QString &label)
{
    const int id = ++m_next;
    job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
    // After the undo manager's own handler, which has pushed the command by
    // then: its serial number names it.
    connect(job, &KJob::result, this, [this, id, results, label](KJob *job) {
        if (!job->error() && !label.isEmpty()) {
            FileUndoManager *undo = FileUndoManager::self();
            m_labels.insert(undo->currentCommandSerialNumber(), label);
            Q_EMIT undoChanged();
        }
        Q_EMIT finished(id, job->error() ? QList<QUrl>() : results, !job->error());
    });
    job->start();
    return id;
}

void FileOps::alert(const QString &text, const QString &detail)
{
    auto *box = new QMessageBox(QMessageBox::Warning, QStringLiteral("Files"), text, QMessageBox::Ok);
    box->setInformativeText(detail);
    box->setAttribute(Qt::WA_DeleteOnClose);
    box->open();
}

int FileOps::newFolder(const QUrl &dir)
{
    QString name = QStringLiteral("untitled folder");
    for (int n = 2; exists(childUrl(dir, name)); ++n)
        name = QStringLiteral("untitled folder %1").arg(n);
    const QUrl url = childUrl(dir, name);
    KIO::MkdirJob *job = KIO::mkdir(url);
    FileUndoManager::self()->recordJob(FileUndoManager::Mkdir, {}, url, job);
    return start(job, {url}, QStringLiteral("New Folder"));
}

int FileOps::rename(const QUrl &url, const QString &name)
{
    if (name.trimmed().isEmpty() || name == url.fileName())
        return -1;
    if (name.contains(QLatin1Char('/')) || name == QLatin1String(".") || name == QLatin1String("..")) {
        alert(QStringLiteral("The name “%1” can’t be used.").arg(name),
              QStringLiteral("Try using a name with fewer characters, or with no punctuation marks."));
        return -1;
    }
    const QUrl to = childUrl(parentUrl(url), name);
    // A case-only change ("notes" to "Notes") is the same file on some disks.
    if (exists(to) && QFileInfo(to.toLocalFile()) != QFileInfo(url.toLocalFile())) {
        alert(QStringLiteral("The name “%1” is already taken. Please choose a different name.").arg(name));
        return -1;
    }
    KIO::CopyJob *job = KIO::moveAs(url, to, KIO::HideProgressInfo);
    FileUndoManager::self()->recordJob(FileUndoManager::Rename, {url}, to, job);
    return start(job, {to}, QStringLiteral("Rename"));
}

int FileOps::duplicate(const QList<QUrl> &urls)
{
    if (urls.isEmpty())
        return -1;
    // A copy job for each, each with its own name; the last one reports.
    QList<QUrl> made;
    for (int i = 0; i < urls.size(); ++i) {
        const QUrl to = childUrl(parentUrl(urls[i]), copyName(urls[i]));
        made << to;
        KIO::CopyJob *job = KIO::copyAs(urls[i], to, KIO::HideProgressInfo);
        FileUndoManager::self()->recordCopyJob(job);
        if (i + 1 < urls.size()) {
            job->setUiDelegate(KIO::createDefaultJobUiDelegate(KJobUiDelegate::AutoHandlingEnabled, nullptr));
            job->start();
        } else {
            return start(job, made, QStringLiteral("Duplicate"));
        }
    }
    return -1;
}

int FileOps::copy(const QList<QUrl> &urls, const QUrl &dir)
{
    if (urls.isEmpty())
        return -1;
    // Into the folder they're in: copies beside them, as Duplicate makes.
    if (std::all_of(urls.begin(), urls.end(), [&](const QUrl &url) { return sameUrl(parentUrl(url), dir); }))
        return duplicate(urls);
    QList<QUrl> made;
    for (const QUrl &url : urls)
        made << childUrl(dir, url.fileName());
    KIO::CopyJob *job = KIO::copy(urls, dir, KIO::HideProgressInfo);
    FileUndoManager::self()->recordCopyJob(job);
    return start(job, made, QStringLiteral("Copy of ") + itemsText(urls));
}

int FileOps::move(const QList<QUrl> &urls, const QUrl &dir)
{
    // Not where they already are, nor into themselves.
    QList<QUrl> moving;
    for (const QUrl &url : urls)
        if (!sameUrl(parentUrl(url), dir) && !sameUrl(url, dir) && !url.isParentOf(dir))
            moving << url;
    if (moving.isEmpty())
        return -1;
    QList<QUrl> made;
    for (const QUrl &url : moving)
        made << childUrl(dir, url.fileName());
    KIO::CopyJob *job = KIO::move(moving, dir, KIO::HideProgressInfo);
    FileUndoManager::self()->recordCopyJob(job);
    return start(job, made, QStringLiteral("Move of ") + itemsText(moving));
}

int FileOps::trash(const QList<QUrl> &urls)
{
    if (urls.isEmpty())
        return -1;
    KIO::CopyJob *job = KIO::trash(urls, KIO::HideProgressInfo);
    FileUndoManager::self()->recordJob(FileUndoManager::Trash, urls, QUrl(QStringLiteral("trash:/")), job);
    // Finder calls it a move, since that is what it is.
    return start(job, {}, QStringLiteral("Move of ") + itemsText(urls));
}

int FileOps::putBack(const QList<QUrl> &urls)
{
    if (urls.isEmpty())
        return -1;
    return start(KIO::restoreFromTrash(urls, KIO::HideProgressInfo), {}, QString());
}

void FileOps::copyToClipboard(const QList<QUrl> &urls)
{
    if (urls.isEmpty())
        return;
    auto *mime = new QMimeData;
    mime->setUrls(urls);
    KIO::setClipboardDataCut(mime, false);
    QStringList names;
    for (const QUrl &url : urls)
        names << (url.isLocalFile() ? url.toLocalFile() : url.toDisplayString());
    mime->setText(names.join(QLatin1Char('\n')));
    QGuiApplication::clipboard()->setMimeData(mime);
}

int FileOps::paste(const QUrl &dir, bool moving)
{
    const QMimeData *mime = QGuiApplication::clipboard()->mimeData();
    if (!mime || !mime->hasUrls())
        return -1;
    const QList<QUrl> urls = mime->urls();
    if (moving || KIO::isClipboardDataCut(mime)) {
        const int id = move(urls, dir);
        if (!moving && id >= 0)
            QGuiApplication::clipboard()->clear(); // what was cut is pasted once
        return id;
    }
    return copy(urls, dir);
}

bool FileOps::dropMoves(const QList<QUrl> &urls, const QUrl &dir) const
{
    if (dir.scheme() == QLatin1String("trash"))
        return true;
    if (!dir.isLocalFile()) {
        return std::all_of(urls.begin(), urls.end(), [&](const QUrl &url) { return url.scheme() == dir.scheme() && url.host() == dir.host(); });
    }
    struct stat to;
    if (::stat(QFile::encodeName(dir.toLocalFile()).constData(), &to) != 0)
        return false;
    return std::all_of(urls.begin(), urls.end(), [&](const QUrl &url) {
        struct stat from;
        return url.isLocalFile() && ::stat(QFile::encodeName(url.toLocalFile()).constData(), &from) == 0 && from.st_dev == to.st_dev;
    });
}

void FileOps::undo()
{
    FileUndoManager *undo = FileUndoManager::self();
    if (!undo->isUndoAvailable())
        return;
    undoUi->ask = m_labels.value(undo->currentCommandSerialNumber()) != QLatin1String("New Folder");
    undo->undo();
}

void FileOps::redo()
{
    FileUndoManager::self()->redo();
}
