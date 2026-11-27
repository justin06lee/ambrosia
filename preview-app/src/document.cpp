#include "document.h"
#include "pages.h"

#include <QElapsedTimer>
#include <QPdfBookmarkModel>
#include <QPdfDocument>
#include <QPdfLink>
#include <QPdfSearchModel>
#include <QPdfSelection>
#include <QPolygonF>

#include <functional>

namespace
{
int s_next = 1;
}

Document::Document(QObject *parent)
    : QObject(parent)
    , m_id(QString::number(s_next++))
    // A page still being drawn on the image thread may hold the last
    // reference: the document is deleted on its own thread either way.
    , m_document(new QPdfDocument, [](QPdfDocument *document) { document->deleteLater(); })
    , m_search(new QPdfSearchModel(this))
{
    m_search->setDocument(m_document.get());
    Pages::add(m_id, m_document);
    m_searchTimer.setInterval(0);
    connect(&m_searchTimer, &QTimer::timeout, this, &Document::searchMore);
}

Document::~Document()
{
    Pages::remove(m_id);
}

int Document::pageCount() const
{
    return m_locked || m_failed ? 0 : m_document->pageCount();
}

void Document::setSource(const QUrl &source)
{
    if (source == m_source)
        return;
    m_source = source;
    Q_EMIT sourceChanged();
    load();
}

bool Document::unlock(const QString &password)
{
    m_document->setPassword(password);
    load();
    return !m_locked && !m_failed;
}

void Document::load()
{
    m_pageSizes.clear();
    m_outline.clear();
    m_lines.clear();
    m_locked = false;
    m_failed = false;
    setFind(QString());
    if (m_source.isEmpty()) {
        m_document->close();
        Q_EMIT loaded();
        return;
    }
    const QPdfDocument::Error error = m_document->load(m_source.toLocalFile());
    m_locked = error == QPdfDocument::Error::IncorrectPassword;
    m_failed = error != QPdfDocument::Error::None && !m_locked;
    if (!m_locked && !m_failed) {
        const int pages = m_document->pageCount();
        m_pageSizes.reserve(pages);
        for (int page = 0; page < pages; ++page)
            m_pageSizes.append(m_document->pagePointSize(page));

        QPdfBookmarkModel bookmarks;
        bookmarks.setDocument(m_document.get());
        const std::function<void(const QModelIndex &)> walk = [&](const QModelIndex &parent) {
            for (int row = 0; row < bookmarks.rowCount(parent); ++row) {
                const QModelIndex index = bookmarks.index(row, 0, parent);
                m_outline.append(QVariantMap{
                    {QStringLiteral("title"), bookmarks.data(index, int(QPdfBookmarkModel::Role::Title))},
                    {QStringLiteral("page"), bookmarks.data(index, int(QPdfBookmarkModel::Role::Page))},
                    {QStringLiteral("level"), bookmarks.data(index, int(QPdfBookmarkModel::Role::Level))},
                    {QStringLiteral("y"), bookmarks.data(index, int(QPdfBookmarkModel::Role::Location)).toPointF().y()},
                });
                walk(index);
            }
        };
        walk({});
    }
    Q_EMIT loaded();
}

void Document::setFind(const QString &text)
{
    if (text == m_find)
        return;
    m_find = text;
    m_matches.clear();
    m_firstOnPage.clear();
    m_searched = 0;
    ++m_matchRevision;
    m_search->setSearchString(text);
    if (text.isEmpty() || pageCount() == 0)
        m_searchTimer.stop();
    else
        m_searchTimer.start();
    Q_EMIT findChanged();
    Q_EMIT matchesChanged();
}

void Document::searchMore()
{
    // A few milliseconds' worth of pages at a time, so typing and scrolling
    // carry on while a long document is gone through.
    QElapsedTimer spent;
    spent.start();
    const int pages = pageCount();
    while (m_searched < pages && spent.elapsed() < 10) {
        const QList<QPdfLink> found = m_search->resultsOnPage(m_searched);
        m_firstOnPage.append(found.isEmpty() ? -1 : int(m_matches.size()));
        for (const QPdfLink &link : found)
            m_matches.append({m_searched, link.rectangles()});
        ++m_searched;
    }
    if (m_searched >= pages)
        m_searchTimer.stop();
    ++m_matchRevision;
    Q_EMIT matchesChanged();
}

QVariantList Document::matchesOn(int page) const
{
    QVariantList rects;
    if (page < 0 || page >= m_firstOnPage.size() || m_firstOnPage.at(page) < 0)
        return rects;
    for (int i = m_firstOnPage.at(page); i < m_matches.size() && m_matches.at(i).page == page; ++i) {
        for (const QRectF &rect : m_matches.at(i).rects) {
            rects.append(QVariantMap{
                {QStringLiteral("match"), i},
                {QStringLiteral("x"), rect.x()},
                {QStringLiteral("y"), rect.y()},
                {QStringLiteral("width"), rect.width()},
                {QStringLiteral("height"), rect.height()},
            });
        }
    }
    return rects;
}

QVariantMap Document::match(int index) const
{
    if (index < 0 || index >= m_matches.size())
        return {};
    const Match &match = m_matches.at(index);
    const QRectF first = match.rects.isEmpty() ? QRectF() : match.rects.first();
    return {
        {QStringLiteral("page"), match.page},
        {QStringLiteral("x"), first.x()},
        {QStringLiteral("y"), first.y()},
    };
}

int Document::matchFrom(int page) const
{
    for (int at = qMax(0, page); at < m_firstOnPage.size(); ++at) {
        if (m_firstOnPage.at(at) >= 0)
            return m_firstOnPage.at(at);
    }
    return m_matches.isEmpty() ? -1 : 0;
}

QVariantMap Document::packed(const QPdfSelection &selection)
{
    QVariantList rects;
    const QList<QPolygonF> bounds = selection.bounds();
    for (const QPolygonF &polygon : bounds) {
        const QRectF rect = polygon.boundingRect();
        rects.append(QVariantMap{
            {QStringLiteral("x"), rect.x()},
            {QStringLiteral("y"), rect.y()},
            {QStringLiteral("width"), rect.width()},
            {QStringLiteral("height"), rect.height()},
        });
    }
    return {
        {QStringLiteral("text"), selection.text()},
        {QStringLiteral("rects"), rects},
    };
}

QPointF Document::onText(int page, QPointF point) const
{
    auto found = m_lines.constFind(page);
    if (found == m_lines.constEnd()) {
        QList<QRectF> lines;
        const QList<QPolygonF> bounds = m_document->getAllText(page).bounds();
        for (const QPolygonF &polygon : bounds) {
            const QRectF rect = polygon.boundingRect();
            if (rect.width() > 0 && rect.height() > 0)
                lines.append(rect);
        }
        found = m_lines.insert(page, lines);
    }
    // The line nearest in height (the one the point is beside, if any),
    // then the nearest place along it.
    const QRectF *nearest = nullptr;
    qreal least = 0;
    for (const QRectF &line : *found) {
        const qreal above = line.top() - point.y(), below = point.y() - line.bottom();
        const qreal across = qMax(qMax(line.left() - point.x(), point.x() - line.right()), qreal(0));
        const qreal distance = qMax(qMax(above, below), qreal(0)) * 1000 + across;
        if (!nearest || distance < least) {
            nearest = &line;
            least = distance;
        }
    }
    if (!nearest)
        return point;
    return QPointF(qBound(nearest->left() + 0.5, point.x(), nearest->right() - 0.5), nearest->center().y());
}

QVariantMap Document::select(int page, QPointF from, QPointF to) const
{
    if (page < 0 || page >= pageCount())
        return {};
    // PDFium selects between two letters: a drag that begins or ends off
    // the text takes the nearest line's, as a Mac's does.
    return packed(m_document->getSelection(page, onText(page, from), onText(page, to)));
}

QVariantMap Document::selectAll(int page) const
{
    if (page < 0 || page >= pageCount())
        return {};
    return packed(m_document->getAllText(page));
}

QString Document::allText() const
{
    QString text;
    const int pages = pageCount();
    for (int page = 0; page < pages; ++page) {
        const QString on = m_document->getAllText(page).text();
        if (on.isEmpty())
            continue;
        if (!text.isEmpty())
            text += QLatin1Char('\n');
        text += on;
    }
    return text;
}
