#include "pages.h"

#include <QHash>
#include <QMutex>
#include <QPainter>
#include <QPdfDocument>

namespace
{
QMutex s_lock;
QHash<QString, std::shared_ptr<QPdfDocument>> s_documents;
}

Pages::Pages()
    : QQuickImageProvider(QQuickImageProvider::Image, QQmlImageProviderBase::ForceAsynchronousImageLoading)
{
}

void Pages::add(const QString &id, const std::shared_ptr<QPdfDocument> &document)
{
    QMutexLocker locker(&s_lock);
    s_documents.insert(id, document);
}

void Pages::remove(const QString &id)
{
    QMutexLocker locker(&s_lock);
    s_documents.remove(id);
}

QImage Pages::requestImage(const QString &id, QSize *size, const QSize &requested)
{
    const qsizetype slash = id.lastIndexOf(QLatin1Char('/'));
    std::shared_ptr<QPdfDocument> document;
    {
        QMutexLocker locker(&s_lock);
        document = s_documents.value(id.left(slash));
    }
    const int page = id.mid(slash + 1).toInt();
    if (!document || page < 0 || page >= document->pageCount())
        return {};
    const QSizeF points = document->pagePointSize(page);
    if (points.isEmpty())
        return {};
    // The size asked for; a width alone takes the page's shape, nothing the
    // page's own size in points.
    QSize want = requested;
    if (want.width() <= 0 && want.height() <= 0)
        want = points.toSize();
    else if (want.height() <= 0)
        want.setHeight(qRound(want.width() * points.height() / points.width()));
    else if (want.width() <= 0)
        want.setWidth(qRound(want.height() * points.width() / points.height()));
    const int longer = qMax(want.width(), want.height());
    if (longer > longest)
        want = QSize(qMax(1, want.width() * longest / longer), qMax(1, want.height() * longest / longer));
    const QImage drawn = document->render(page, want);
    if (drawn.isNull())
        return {};
    // PDFium leaves what the page doesn't paint transparent: paper is white.
    QImage paper(drawn.size(), QImage::Format_RGB32);
    paper.fill(Qt::white);
    QPainter painter(&paper);
    painter.drawImage(0, 0, drawn);
    painter.end();
    if (size)
        *size = paper.size();
    return paper;
}
