#pragma once

#include <QHash>
#include <QList>
#include <QObject>
#include <QPointF>
#include <QRectF>
#include <QString>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include <memory>

class QPdfDocument;
class QPdfSearchModel;
class QPdfSelection;

// A PDF open in a window: its pages' sizes (in points, 72 to the inch, from
// the top left as Qt's PDF classes give them), its outline, the text found
// in it and the text a drag selects. Its pages are drawn by Pages
// (image://page/ID/PAGE).
class Document : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QString id READ id CONSTANT)
    Q_PROPERTY(int pageCount READ pageCount NOTIFY loaded)
    // Each page's size in points.
    Q_PROPERTY(QVariantList pageSizes READ pageSizes NOTIFY loaded)
    // It wants a password before it shows anything.
    Q_PROPERTY(bool locked READ locked NOTIFY loaded)
    // It couldn't be read (and isn't just locked).
    Q_PROPERTY(bool failed READ failed NOTIFY loaded)
    // The table of contents, flat: [{title, page, level, y}].
    Q_PROPERTY(QVariantList outline READ outline NOTIFY loaded)
    // What is being looked for; the matches come in page by page.
    Q_PROPERTY(QString find READ find WRITE setFind NOTIFY findChanged)
    Q_PROPERTY(int matchCount READ matchCount NOTIFY matchesChanged)
    Q_PROPERTY(bool searching READ searching NOTIFY matchesChanged)
    // Goes up whenever the matches change, for what draws them to ask again.
    Q_PROPERTY(int matchRevision READ matchRevision NOTIFY matchesChanged)

public:
    explicit Document(QObject *parent = nullptr);
    ~Document() override;

    QUrl source() const { return m_source; }
    void setSource(const QUrl &source);
    QString id() const { return m_id; }
    int pageCount() const;
    QVariantList pageSizes() const { return m_pageSizes; }
    bool locked() const { return m_locked; }
    bool failed() const { return m_failed; }
    QVariantList outline() const { return m_outline; }
    QString find() const { return m_find; }
    void setFind(const QString &text);
    int matchCount() const { return int(m_matches.size()); }
    bool searching() const { return m_searchTimer.isActive(); }
    int matchRevision() const { return m_matchRevision; }

    // True when the password opens it.
    Q_INVOKABLE bool unlock(const QString &password);
    // The matches on a page, a rectangle each (a match over two lines has
    // two): [{match, x, y, width, height}].
    Q_INVOKABLE QVariantList matchesOn(int page) const;
    // Where a match is: {page, x, y}.
    Q_INVOKABLE QVariantMap match(int index) const;
    // The first match on or after a page (or the first of all), -1 if none.
    Q_INVOKABLE int matchFrom(int page) const;
    // The text between two points of a page: {text, rects: [{x, y, width, height}]}.
    Q_INVOKABLE QVariantMap select(int page, QPointF from, QPointF to) const;
    // All of a page's text, the same way.
    Q_INVOKABLE QVariantMap selectAll(int page) const;
    // Every page's text, one after another.
    Q_INVOKABLE QString allText() const;

Q_SIGNALS:
    void sourceChanged();
    void loaded();
    void findChanged();
    void matchesChanged();

private:
    struct Match {
        int page;
        QList<QRectF> rects;
    };
    void load();
    // A point moved onto the nearest line of the page's text.
    QPointF onText(int page, QPointF point) const;
    void searchMore();
    static QVariantMap packed(const QPdfSelection &selection);

    QUrl m_source;
    QString m_id;
    std::shared_ptr<QPdfDocument> m_document;
    QPdfSearchModel *m_search = nullptr;
    QVariantList m_pageSizes;
    QVariantList m_outline;
    bool m_locked = false;
    bool m_failed = false;
    QString m_find;
    QList<Match> m_matches;
    // Where each page's lines of text are, found when first asked for.
    mutable QHash<int, QList<QRectF>> m_lines;
    QList<int> m_firstOnPage; // the first match's index, per page searched; -1 for none
    int m_searched = 0;
    int m_matchRevision = 0;
    QTimer m_searchTimer;
};
