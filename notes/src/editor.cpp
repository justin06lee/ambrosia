#include "editor.h"

#include <QClipboard>
#include <QFont>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QLocale>
#include <QMimeData>
#include <QPageLayout>
#include <QPageSize>
#include <QPdfWriter>
#include <QTextCursor>
#include <QTextDocument>
#include <QTextList>

#include <memory>

namespace
{
// What a paragraph's format holds beyond Qt's own: its kind, a list item's
// level, a checklist item's mark, whether it is quoted. And a character's:
// bold by choice (a heading's weight is its kind's, not this).
enum Property {
    KindProperty = QTextFormat::UserProperty + 1,
    LevelProperty,
    CheckedProperty,
    QuoteProperty,
    BoldProperty,
};
enum Kind { Body, Title, Heading, Subheading, Mono, Bullet, Dash, Number, Check };
const char *const kindNames[] = {"body", "title", "heading", "subheading", "mono", "bullet", "dash", "number", "check"};
const int kindCount = 9;
const int deepest = 8;
// Where a list item's text begins after its mark, how much further each
// level in, and a quoted paragraph's after its bar.
const qreal listInset = 23, checkInset = 28, levelInset = 30, quoteInset = 14;
const QString ourMime = QStringLiteral("application/x-ambrosia-notes");

int kindNamed(const QString &name)
{
    for (int kind = 0; kind < kindCount; ++kind) {
        if (name == QLatin1String(kindNames[kind]))
            return kind;
    }
    return Body;
}

QString nameOf(int kind)
{
    return QString::fromLatin1(kindNames[qBound(0, kind, kindCount - 1)]);
}

bool isList(int kind)
{
    return kind >= Bullet;
}

bool headed(int kind)
{
    return kind == Title || kind == Heading || kind == Subheading;
}

int sizeOf(int kind)
{
    return kind == Title ? 22 : kind == Heading ? 17 : kind == Subheading ? 15 : 13;
}

int kindOf(const QTextBlockFormat &format)
{
    return qBound(0, format.intProperty(KindProperty), kindCount - 1);
}

int levelOf(const QTextBlockFormat &format)
{
    return qBound(0, format.intProperty(LevelProperty), deepest);
}

QVariantMap runOf(const QString &text, bool bold, bool italic, bool underline, bool strike)
{
    return {
        {QStringLiteral("text"), text},
        {QStringLiteral("bold"), bold},
        {QStringLiteral("italic"), italic},
        {QStringLiteral("underline"), underline},
        {QStringLiteral("strike"), strike},
    };
}

QString textOf(const QVariantMap &paragraph)
{
    QString text;
    const QVariantList runs = paragraph.value(QStringLiteral("runs")).toList();
    for (const QVariant &run : runs)
        text += run.toMap().value(QStringLiteral("text")).toString();
    return text;
}
}

Editor::Editor(QObject *parent)
    : QObject(parent)
{
    // One word for a cursor that moved, a selection that changed and text
    // that did, however many of them came together.
    m_changed.setSingleShot(true);
    m_changed.setInterval(0);
    connect(&m_changed, &QTimer::timeout, this, &Editor::formatChanged);
    m_told.setSingleShot(true);
    m_told.setInterval(0);
    connect(&m_told, &QTimer::timeout, this, &Editor::edited);
}

QTextDocument *Editor::text_() const
{
    return m_document ? m_document->textDocument() : nullptr;
}

void Editor::setDocument(QQuickTextDocument *document)
{
    if (m_document == document)
        return;
    if (m_connected)
        m_connected->disconnect(this);
    m_document = document;
    m_connected = text_();
    m_pendingAt = -1;
    if (m_connected)
        connect(m_connected, &QTextDocument::contentsChange, this, &Editor::contentsChanged);
    Q_EMIT documentChanged();
    remark();
    m_changed.start();
}

void Editor::setMonoFamily(const QString &family)
{
    if (m_mono == family || family.isEmpty())
        return;
    m_mono = family;
    Q_EMIT monoFamilyChanged();
}

void Editor::moved()
{
    if (m_pendingAt >= 0 && (m_cursor != m_pendingAt || m_start != m_end))
        m_pendingAt = -1;
    Q_EMIT selectionChanged();
    m_changed.start();
}

void Editor::setCursorPosition(int position)
{
    if (m_cursor == position)
        return;
    m_cursor = position;
    moved();
}

void Editor::setSelectionStart(int position)
{
    if (m_start == position)
        return;
    m_start = position;
    moved();
}

void Editor::setSelectionEnd(int position)
{
    if (m_end == position)
        return;
    m_end = position;
    moved();
}

// A kind's characters: its size and weight, the marks chosen for them, and
// for monostyled text its family.
QTextCharFormat Editor::dress(int kind, const Marks &marks) const
{
    QTextCharFormat format;
    format.setProperty(QTextFormat::FontPixelSize, sizeOf(kind));
    format.setFontWeight(headed(kind) || marks.bold ? QFont::Bold : QFont::Normal);
    format.setProperty(BoldProperty, marks.bold);
    format.setFontItalic(marks.italic);
    format.setFontUnderline(marks.underline);
    format.setFontStrikeOut(marks.strike);
    if (kind == Mono) {
        format.setFontFamilies({m_mono});
        format.setFontFixedPitch(true);
    }
    return format;
}

// A paragraph's format: what it is, and the inset that leaves room for
// what is drawn before it.
QTextBlockFormat Editor::shape(int kind, int level, bool checked, bool quote) const
{
    QTextBlockFormat format;
    const int depth = isList(kind) ? qBound(0, level, deepest) : 0;
    format.setProperty(KindProperty, kind);
    format.setProperty(LevelProperty, depth);
    format.setProperty(CheckedProperty, kind == Check && checked);
    format.setProperty(QuoteProperty, quote);
    qreal left = quote ? quoteInset : 0;
    if (isList(kind))
        left += (kind == Check ? checkInset : listInset) + depth * levelInset;
    format.setLeftMargin(left);
    // A line more between lines than the type's own, as Notes sets them.
    format.setLineHeight(1, QTextBlockFormat::LineDistanceHeight);
    return format;
}

namespace
{
struct Read {
    bool bold, italic, underline, strike;
};
Read marksIn(const QTextCharFormat &format)
{
    return {format.boolProperty(BoldProperty), format.fontItalic(), format.fontUnderline(), format.fontStrikeOut()};
}
}

QTextCharFormat Editor::charFormat() const
{
    QTextDocument *document = text_();
    if (!document)
        return {};
    if (m_pendingAt >= 0 && m_start == m_end && m_pendingAt == m_cursor)
        return m_pending;
    const int last = document->characterCount() - 1;
    QTextCursor cursor(document);
    // A cursor's format is that of the character before it: for a
    // selection, the first one in it.
    cursor.setPosition(qBound(0, m_start != m_end ? qMin(m_start + 1, m_end) : m_cursor, last));
    return cursor.charFormat();
}

QTextBlock Editor::block_() const
{
    const QTextDocument *document = text_();
    return document ? document->findBlock(m_start != m_end ? m_start : m_cursor) : QTextBlock();
}

bool Editor::bold() const { return charFormat().boolProperty(BoldProperty); }
bool Editor::italic() const { return charFormat().fontItalic(); }
bool Editor::underline() const { return charFormat().fontUnderline(); }
bool Editor::strike() const { return charFormat().fontStrikeOut(); }
QString Editor::kind() const { return nameOf(kindOf(block_().blockFormat())); }
bool Editor::quote() const { return block_().blockFormat().boolProperty(QuoteProperty); }
bool Editor::checked() const { return block_().blockFormat().boolProperty(CheckedProperty); }

void Editor::contentsChanged(int position, int removed, int added)
{
    if (m_loading)
        return;
    if (m_pendingAt >= 0 && added > 0 && position == m_pendingAt) {
        m_typed = m_pending;
        m_typedAt = m_pendingAt;
    }
    m_pendingAt = -1;
    m_touchedFrom = m_touchedFrom < 0 ? position : qMin(m_touchedFrom, position);
    m_touchedTo = qMax(m_touchedTo, position + added);
    m_added = removed == 0 ? added : 0;
    if (!m_settling) {
        m_settling = true;
        QMetaObject::invokeMethod(this, &Editor::settle, Qt::QueuedConnection);
    }
    m_changed.start();
}

// A paragraph as its kind has it: its inset, and every character in the
// kind's size and weight with only its marks kept. True when it wasn't.
bool Editor::tidy(const QTextBlock &block)
{
    bool changed = false;
    const QTextBlockFormat have = block.blockFormat();
    int kind = kindOf(have);
    // A list of Qt's own (pasted or dropped in): ours of the like kind.
    if (QTextList *list = block.textList()) {
        if (kind == Body)
            kind = list->format().style() <= QTextListFormat::ListDecimal ? Number : Bullet;
        list->remove(block);
        changed = true;
    }
    const QTextBlockFormat want = shape(kind, levelOf(have), have.boolProperty(CheckedProperty), have.boolProperty(QuoteProperty));
    if (changed || have != want) {
        QTextCursor(block).setBlockFormat(want);
        changed = true;
    }
    struct Piece {
        int from, to;
        QTextCharFormat format;
    };
    QList<Piece> pieces;
    for (auto it = block.begin(); !it.atEnd(); ++it) {
        const QTextFragment fragment = it.fragment();
        const Read read = marksIn(fragment.charFormat());
        const QTextCharFormat format = dress(kind, {read.bold, read.italic, read.underline, read.strike});
        if (fragment.charFormat() != format)
            pieces.append({fragment.position(), fragment.position() + fragment.length(), format});
    }
    QTextCursor cursor(block);
    for (const Piece &piece : std::as_const(pieces)) {
        cursor.setPosition(piece.from);
        cursor.setPosition(piece.to, QTextCursor::KeepAnchor);
        cursor.setCharFormat(piece.format);
        changed = true;
    }
    const Read own = marksIn(block.charFormat());
    const QTextCharFormat format = dress(kind, {own.bold, own.italic, own.underline, own.strike});
    if (block.charFormat() != format) {
        QTextCursor(block).setBlockCharFormat(format);
        changed = true;
    }
    return changed;
}

// After a change of the TextEdit's own, as one step with it for Undo: what
// was just typed takes the marks chosen for it; every paragraph the change
// touched is dressed as its kind; and "* ", "- " or "1. " typed where a
// paragraph of body text begins makes it a list's item.
void Editor::settle()
{
    m_settling = false;
    QTextDocument *document = text_();
    const int from = m_touchedFrom, to = m_touchedTo, typedAt = m_typedAt, added = m_added;
    m_touchedFrom = m_touchedTo = m_typedAt = -1;
    m_added = 0;
    if (!document || from < 0)
        return;
    m_loading = true;
    const int last = document->characterCount() - 1;
    // Looked at first, changed after: an edit block that changes nothing
    // would still close the step before it.
    const bool typed = typedAt >= 0 && m_cursor > typedAt && m_cursor <= last;
    int list = -1;
    QTextBlock at = document->findBlock(qBound(0, m_cursor, last));
    if (added == 1 && m_start == m_end && at.isValid() && kindOf(at.blockFormat()) == Body && m_cursor == at.position() + at.length() - 1) {
        const QString text = at.text();
        list = text == QLatin1String("* ") ? Bullet : text == QLatin1String("- ") ? Dash : text == QLatin1String("1. ") ? Number : -1;
    }
    bool untidy = typed || list >= 0;
    QList<QTextBlock> blocks;
    for (QTextBlock block = document->findBlock(qBound(0, from, last)); block.isValid() && block.position() <= to; block = block.next())
        blocks.append(block);
    if (!untidy) {
        // (A copy of the document is not at hand to try on: ask each block
        // what tidy() would ask.)
        for (const QTextBlock &block : std::as_const(blocks)) {
            const QTextBlockFormat have = block.blockFormat();
            const int kind = kindOf(have);
            if (block.textList() || have != shape(kind, levelOf(have), have.boolProperty(CheckedProperty), have.boolProperty(QuoteProperty))) {
                untidy = true;
                break;
            }
            const Read own = marksIn(block.charFormat());
            if (block.charFormat() != dress(kind, {own.bold, own.italic, own.underline, own.strike})) {
                untidy = true;
                break;
            }
            for (auto it = block.begin(); !it.atEnd() && !untidy; ++it) {
                const Read read = marksIn(it.fragment().charFormat());
                untidy = it.fragment().charFormat() != dress(kind, {read.bold, read.italic, read.underline, read.strike});
            }
            if (untidy)
                break;
        }
    }
    if (untidy) {
        QTextCursor cursor(document);
        cursor.joinPreviousEditBlock();
        if (typed) {
            cursor.setPosition(typedAt);
            cursor.setPosition(m_cursor, QTextCursor::KeepAnchor);
            cursor.setCharFormat(m_typed);
        }
        for (const QTextBlock &block : std::as_const(blocks))
            tidy(block);
        if (list >= 0) {
            const bool quoted = at.blockFormat().boolProperty(QuoteProperty);
            cursor.setPosition(at.position());
            cursor.setPosition(at.position() + at.length() - 1, QTextCursor::KeepAnchor);
            cursor.removeSelectedText();
            cursor.setBlockFormat(shape(list, 0, false, quoted));
        }
        cursor.endEditBlock();
    }
    m_loading = false;
    remark();
    m_changed.start();
    m_told.start();
}

// The marks before list items and the bars beside quotes, as the document
// now stands. A numbered item counts on from the one before it at its
// level; an item of another kind at its level or above, or anything that
// is no item, starts the count again (as notes.mjs writes the numbers).
void Editor::remark()
{
    QVariantList made;
    const QTextDocument *document = text_();
    QList<int> numbers;
    for (QTextBlock block = document ? document->begin() : QTextBlock(); block.isValid(); block = block.next()) {
        const QTextBlockFormat format = block.blockFormat();
        const int kind = kindOf(format), level = isList(kind) ? levelOf(format) : 0;
        const bool quoted = format.boolProperty(QuoteProperty);
        int number = 0;
        if (kind == Number) {
            numbers.resize(level + 1);
            number = ++numbers[level];
        } else if (isList(kind)) {
            if (numbers.size() > level)
                numbers.resize(level);
        } else {
            numbers.clear();
        }
        if (!isList(kind) && !quoted)
            continue;
        made.append(QVariantMap{
            {QStringLiteral("kind"), nameOf(kind)},
            {QStringLiteral("level"), level},
            {QStringLiteral("checked"), format.boolProperty(CheckedProperty)},
            {QStringLiteral("number"), number},
            {QStringLiteral("quote"), quoted},
            {QStringLiteral("start"), block.position()},
            {QStringLiteral("last"), block.position() + block.length() - 1},
            {QStringLiteral("x"), format.leftMargin()},
        });
    }
    if (made == m_markers)
        return;
    m_markers = made;
    Q_EMIT markersChanged();
}

void Editor::changeChars(const std::function<void(Marks &)> &change)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    if (m_start == m_end) {
        const QTextBlock block = document->findBlock(m_cursor);
        const int kind = kindOf(block.blockFormat());
        const Read read = marksIn(charFormat());
        Marks marks{read.bold, read.italic, read.underline, read.strike};
        change(marks);
        m_pending = dress(kind, marks);
        m_pendingAt = m_cursor;
        // An empty paragraph takes it as its own: what is typed there
        // gets its format from the paragraph.
        if (block.isValid() && block.length() <= 1) {
            m_loading = true;
            QTextCursor(block).setBlockCharFormat(m_pending);
            m_loading = false;
        }
        m_changed.start();
        return;
    }
    struct Piece {
        int from, to;
        QTextCharFormat format;
    };
    QList<Piece> pieces;
    QList<QPair<QTextBlock, QTextCharFormat>> bare;
    for (QTextBlock block = document->findBlock(m_start); block.isValid() && block.position() < m_end; block = block.next()) {
        const int kind = kindOf(block.blockFormat());
        if (block.length() <= 1) {
            const Read read = marksIn(block.charFormat());
            Marks marks{read.bold, read.italic, read.underline, read.strike};
            change(marks);
            bare.append({block, dress(kind, marks)});
        }
        for (auto it = block.begin(); !it.atEnd(); ++it) {
            const QTextFragment fragment = it.fragment();
            const int from = qMax(fragment.position(), m_start), to = qMin(fragment.position() + fragment.length(), m_end);
            if (from >= to)
                continue;
            const Read read = marksIn(fragment.charFormat());
            Marks marks{read.bold, read.italic, read.underline, read.strike};
            change(marks);
            pieces.append({from, to, dress(kind, marks)});
        }
    }
    QTextCursor cursor(document);
    cursor.beginEditBlock();
    for (const Piece &piece : std::as_const(pieces)) {
        cursor.setPosition(piece.from);
        cursor.setPosition(piece.to, QTextCursor::KeepAnchor);
        cursor.setCharFormat(piece.format);
    }
    for (const auto &[block, format] : std::as_const(bare))
        QTextCursor(block).setBlockCharFormat(format);
    cursor.endEditBlock();
    m_changed.start();
}

void Editor::setBold(bool on) { changeChars([on](Marks &marks) { marks.bold = on; }); }
void Editor::setItalic(bool on) { changeChars([on](Marks &marks) { marks.italic = on; }); }
void Editor::setUnderline(bool on) { changeChars([on](Marks &marks) { marks.underline = on; }); }
void Editor::setStrike(bool on) { changeChars([on](Marks &marks) { marks.strike = on; }); }

// Every character of a paragraph in another kind's dress, its marks kept.
void Editor::redress(const QTextBlock &block, int kind)
{
    struct Piece {
        int from, to;
        QTextCharFormat format;
    };
    QList<Piece> pieces;
    for (auto it = block.begin(); !it.atEnd(); ++it) {
        const QTextFragment fragment = it.fragment();
        const Read read = marksIn(fragment.charFormat());
        pieces.append({fragment.position(), fragment.position() + fragment.length(), dress(kind, {read.bold, read.italic, read.underline, read.strike})});
    }
    QTextCursor cursor(block);
    for (const Piece &piece : std::as_const(pieces)) {
        cursor.setPosition(piece.from);
        cursor.setPosition(piece.to, QTextCursor::KeepAnchor);
        cursor.setCharFormat(piece.format);
    }
    const Read own = marksIn(block.charFormat());
    QTextCursor(block).setBlockCharFormat(dress(kind, {own.bold, own.italic, own.underline, own.strike}));
}

void Editor::changeBlocks(const std::function<void(int &, int &, bool &, bool &)> &change)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    const int from = m_start != m_end ? m_start : m_cursor;
    // A selection that ends where a paragraph begins doesn't take it in.
    const int to = m_start != m_end ? m_end - 1 : m_cursor;
    QList<QTextBlock> blocks;
    for (QTextBlock block = document->findBlock(from); block.isValid() && block.position() <= to; block = block.next())
        blocks.append(block);
    QTextCursor cursor(document);
    cursor.beginEditBlock();
    for (const QTextBlock &block : std::as_const(blocks)) {
        const QTextBlockFormat format = block.blockFormat();
        const int was = kindOf(format);
        int kind = was, level = levelOf(format);
        bool checked = format.boolProperty(CheckedProperty), quoted = format.boolProperty(QuoteProperty);
        change(kind, level, checked, quoted);
        if (kind != was)
            redress(block, kind);
        const QTextBlockFormat now = shape(kind, level, checked, quoted);
        if (now != format)
            QTextCursor(block).setBlockFormat(now);
    }
    cursor.endEditBlock();
    m_changed.start();
}

void Editor::setKind(const QString &name)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    int target = kindNamed(name);
    if (isList(target)) {
        const int from = m_start != m_end ? m_start : m_cursor, to = m_start != m_end ? m_end - 1 : m_cursor;
        bool all = true;
        for (QTextBlock block = document->findBlock(from); block.isValid() && block.position() <= to && all; block = block.next())
            all = kindOf(block.blockFormat()) == target;
        if (all)
            target = Body;
    }
    changeBlocks([target](int &kind, int &level, bool &checked, bool &) {
        if (kind != target)
            checked = false;
        kind = target;
        if (!isList(kind))
            level = 0;
    });
}

void Editor::setQuote(bool on)
{
    changeBlocks([on](int &, int &, bool &, bool &quoted) { quoted = on; });
}

void Editor::setChecked(bool on)
{
    changeBlocks([on](int &kind, int &, bool &checked, bool &) {
        if (kind == Check)
            checked = on;
    });
}

void Editor::toggleChecked(int position)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    const QTextBlock block = document->findBlock(position);
    if (!block.isValid())
        return;
    const QTextBlockFormat format = block.blockFormat();
    if (kindOf(format) != Check)
        return;
    QTextCursor(block).setBlockFormat(shape(Check, levelOf(format), !format.boolProperty(CheckedProperty), format.boolProperty(QuoteProperty)));
}

bool Editor::indent(int by)
{
    QTextDocument *document = text_();
    if (!document)
        return false;
    const int from = m_start != m_end ? m_start : m_cursor, to = m_start != m_end ? m_end - 1 : m_cursor;
    bool any = false;
    for (QTextBlock block = document->findBlock(from); block.isValid() && block.position() <= to && !any; block = block.next())
        any = isList(kindOf(block.blockFormat()));
    if (!any)
        return false;
    changeBlocks([by](int &kind, int &level, bool &, bool &) {
        if (isList(kind))
            level = qBound(0, level + by, deepest);
    });
    return true;
}

bool Editor::returnKey()
{
    QTextDocument *document = text_();
    if (!document || m_start != m_end)
        return false;
    const QTextBlock block = document->findBlock(m_cursor);
    const QTextBlockFormat format = block.blockFormat();
    const int kind = kindOf(format), level = levelOf(format);
    const bool quoted = format.boolProperty(QuoteProperty);
    const bool bare = block.length() <= 1;
    QTextCursor cursor(document);
    cursor.setPosition(m_cursor);
    if (isList(kind) && bare) {
        // An empty item: a level out, and at the first level out of the list.
        cursor.beginEditBlock();
        cursor.setBlockFormat(level > 0 ? shape(kind, level - 1, false, quoted) : shape(Body, 0, false, quoted));
        if (level == 0)
            redress(block, Body);
        cursor.endEditBlock();
        m_changed.start();
        return true;
    }
    if (quoted && bare && kind == Body) {
        cursor.setBlockFormat(shape(Body, 0, false, false));
        m_changed.start();
        return true;
    }
    if (headed(kind)) {
        // After a title or a heading comes body text.
        cursor.insertBlock(shape(Body, 0, false, quoted), dress(Body, {}));
        return true;
    }
    if (kind == Check && format.boolProperty(CheckedProperty)) {
        // The next item starts unchecked.
        cursor.insertBlock(shape(Check, level, false, quoted));
        return true;
    }
    return false;
}

bool Editor::backspaceKey()
{
    QTextDocument *document = text_();
    if (!document || m_start != m_end)
        return false;
    const QTextBlock block = document->findBlock(m_cursor);
    if (m_cursor != block.position())
        return false;
    const QTextBlockFormat format = block.blockFormat();
    const int kind = kindOf(format);
    const bool quoted = format.boolProperty(QuoteProperty);
    if (!isList(kind) && !quoted)
        return false;
    QTextCursor cursor(block);
    cursor.beginEditBlock();
    if (isList(kind)) {
        redress(block, Body);
        cursor.setBlockFormat(shape(Body, 0, false, quoted));
    } else {
        cursor.setBlockFormat(shape(kind, 0, false, false));
    }
    cursor.endEditBlock();
    m_changed.start();
    return true;
}

// The paragraphs between two places, the first and the last cut to them.
QVariantList Editor::taken(int from, int to) const
{
    QVariantList list;
    const QTextDocument *document = text_();
    if (!document)
        return list;
    for (QTextBlock block = document->findBlock(from); block.isValid() && block.position() < qMax(to, from + 1); block = block.next()) {
        const QTextBlockFormat format = block.blockFormat();
        QVariantList runs;
        for (auto it = block.begin(); !it.atEnd(); ++it) {
            const QTextFragment fragment = it.fragment();
            const int start = qMax(fragment.position(), from), end = qMin(fragment.position() + fragment.length(), to);
            if (start >= end)
                continue;
            const Read read = marksIn(fragment.charFormat());
            const QString text = fragment.text().mid(start - fragment.position(), end - start);
            if (!runs.isEmpty()) {
                QVariantMap before = runs.last().toMap();
                if (before.value(QStringLiteral("bold")).toBool() == read.bold && before.value(QStringLiteral("italic")).toBool() == read.italic
                    && before.value(QStringLiteral("underline")).toBool() == read.underline && before.value(QStringLiteral("strike")).toBool() == read.strike) {
                    before.insert(QStringLiteral("text"), before.value(QStringLiteral("text")).toString() + text);
                    runs.last() = before;
                    continue;
                }
            }
            runs.append(runOf(text, read.bold, read.italic, read.underline, read.strike));
        }
        list.append(QVariantMap{
            {QStringLiteral("kind"), nameOf(kindOf(format))},
            {QStringLiteral("level"), levelOf(format)},
            {QStringLiteral("checked"), format.boolProperty(CheckedProperty)},
            {QStringLiteral("quote"), format.boolProperty(QuoteProperty)},
            {QStringLiteral("runs"), runs},
        });
        if (to <= from)
            break;
    }
    return list;
}

QVariantList Editor::paragraphs() const
{
    const QTextDocument *document = text_();
    return document ? taken(0, document->characterCount()) : QVariantList();
}

// Paragraphs put in at a cursor: the first into the paragraph the cursor
// is in (which takes its kind if it was empty), each of the others in one
// of its own.
void Editor::put(QTextCursor &cursor, const QVariantList &paragraphs)
{
    bool first = true;
    for (const QVariant &entry : paragraphs) {
        const QVariantMap paragraph = entry.toMap();
        int kind = kindNamed(paragraph.value(QStringLiteral("kind")).toString());
        const QTextBlockFormat format = shape(kind, paragraph.value(QStringLiteral("level")).toInt(), paragraph.value(QStringLiteral("checked")).toBool(),
                                              paragraph.value(QStringLiteral("quote")).toBool());
        if (!first) {
            cursor.insertBlock(format, dress(kind, {}));
        } else if (cursor.block().length() <= 1) {
            cursor.setBlockFormat(format);
            cursor.setBlockCharFormat(dress(kind, {}));
        } else {
            kind = kindOf(cursor.blockFormat());
        }
        first = false;
        const QVariantList runs = paragraph.value(QStringLiteral("runs")).toList();
        for (const QVariant &each : runs) {
            const QVariantMap run = each.toMap();
            cursor.insertText(run.value(QStringLiteral("text")).toString(),
                              dress(kind, {run.value(QStringLiteral("bold")).toBool(), run.value(QStringLiteral("italic")).toBool(),
                                           run.value(QStringLiteral("underline")).toBool(), run.value(QStringLiteral("strike")).toBool()}));
        }
    }
}

void Editor::setParagraphs(const QVariantList &paragraphs)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    m_loading = true;
    m_pendingAt = -1;
    // What was still to be settled or told of the note before is dropped:
    // it is not this one's.
    m_touchedFrom = m_touchedTo = m_typedAt = -1;
    m_told.stop();
    // The marks go first: they say places in the text that is going.
    if (!m_markers.isEmpty()) {
        m_markers.clear();
        Q_EMIT markersChanged();
    }
    document->setUndoRedoEnabled(false);
    document->clear();
    QTextCursor cursor(document);
    cursor.beginEditBlock();
    if (paragraphs.isEmpty()) {
        cursor.setBlockFormat(shape(Body, 0, false, false));
        cursor.setBlockCharFormat(dress(Body, {}));
    } else {
        put(cursor, paragraphs);
    }
    cursor.endEditBlock();
    document->setUndoRedoEnabled(true);
    document->setModified(false);
    m_loading = false;
    remark();
    m_changed.start();
}

void Editor::copy()
{
    if (m_start == m_end)
        return;
    const QVariantList list = taken(m_start, m_end);
    // As text: a line a paragraph, a list's items marked as Markdown's.
    QStringList lines;
    QList<int> numbers;
    for (const QVariant &entry : list) {
        const QVariantMap paragraph = entry.toMap();
        const int kind = kindNamed(paragraph.value(QStringLiteral("kind")).toString());
        const int level = isList(kind) ? paragraph.value(QStringLiteral("level")).toInt() : 0;
        QString mark;
        if (kind == Number) {
            numbers.resize(level + 1);
            mark = QString::number(++numbers[level]) + QStringLiteral(". ");
        } else if (isList(kind)) {
            if (numbers.size() > level)
                numbers.resize(level);
            mark = kind == Check ? (paragraph.value(QStringLiteral("checked")).toBool() ? QStringLiteral("- [x] ") : QStringLiteral("- [ ] ")) : QStringLiteral("- ");
        } else {
            numbers.clear();
        }
        lines.append(QString(level, QLatin1Char('\t')) + (list.size() > 1 ? mark : QString()) + textOf(paragraph).replace(QChar::LineSeparator, QLatin1Char('\n')));
    }
    auto *data = new QMimeData;
    data->setText(lines.join(QLatin1Char('\n')));
    data->setData(ourMime, QJsonDocument(QJsonArray::fromVariantList(list)).toJson(QJsonDocument::Compact));
    QGuiApplication::clipboard()->setMimeData(data);
}

void Editor::cut()
{
    QTextDocument *document = text_();
    if (!document || m_start == m_end)
        return;
    copy();
    QTextCursor cursor(document);
    cursor.setPosition(m_start);
    cursor.setPosition(m_end, QTextCursor::KeepAnchor);
    cursor.removeSelectedText();
}

void Editor::paste()
{
    QTextDocument *document = text_();
    const QMimeData *data = QGuiApplication::clipboard()->mimeData();
    if (!document || !data)
        return;
    QVariantList ours;
    if (data->hasFormat(ourMime))
        ours = QJsonDocument::fromJson(data->data(ourMime)).array().toVariantList();
    if (ours.isEmpty() && !data->hasText())
        return;
    QTextCursor cursor(document);
    cursor.setPosition(m_start);
    cursor.setPosition(m_end, QTextCursor::KeepAnchor);
    cursor.beginEditBlock();
    cursor.removeSelectedText();
    if (!ours.isEmpty())
        put(cursor, ours);
    else
        cursor.insertText(data->text());
    cursor.endEditBlock();
}

bool Editor::exportPdf(const QUrl &file, const QString &title) const
{
    const QTextDocument *document = text_();
    if (!document)
        return false;
    QPdfWriter writer(file.toLocalFile());
    writer.setTitle(title);
    writer.setCreator(QStringLiteral("Notes"));
    writer.setPageSize(QPageSize(QLocale().measurementSystem() == QLocale::MetricSystem ? QPageSize::A4 : QPageSize::Letter));
    // An inch all round: QTextDocument::print puts two centimetres of its
    // own inside the page's margins.
    const qreal margin = 72 - 2 / 2.54 * 72;
    writer.setPageMargins(QMarginsF(margin, margin, margin, margin), QPageLayout::Point);
    // On paper the marks are text: a copy with each written before its
    // item, in points for the window's pixels.
    QTextDocument paper;
    QFont font = document->defaultFont();
    font.setPointSizeF(sizeOf(Body));
    paper.setDefaultFont(font);
    QTextCursor cursor(&paper);
    bool first = true;
    QList<int> numbers;
    const QVariantList list = paragraphs();
    for (const QVariant &entry : list) {
        const QVariantMap paragraph = entry.toMap();
        const int kind = kindNamed(paragraph.value(QStringLiteral("kind")).toString());
        const int level = isList(kind) ? paragraph.value(QStringLiteral("level")).toInt() : 0;
        const bool quoted = paragraph.value(QStringLiteral("quote")).toBool();
        QString mark;
        if (kind == Number) {
            numbers.resize(level + 1);
            mark = QString::number(++numbers[level]) + QStringLiteral(".  ");
        } else if (isList(kind)) {
            if (numbers.size() > level)
                numbers.resize(level);
            mark = kind == Bullet ? QStringLiteral("•  ") : kind == Dash ? QStringLiteral("–  ")
                 : paragraph.value(QStringLiteral("checked")).toBool() ? QStringLiteral("☑  ") : QStringLiteral("☐  ");
        } else {
            numbers.clear();
        }
        QTextBlockFormat block;
        block.setLeftMargin((quoted ? 2 * quoteInset : 0) + (isList(kind) ? 8 + level * levelInset : 0));
        const auto dressed = [&](bool bold, bool italic, bool underline, bool strike) {
            QTextCharFormat format;
            format.setFontPointSize(sizeOf(kind));
            format.setFontWeight(headed(kind) || bold ? QFont::Bold : QFont::Normal);
            format.setFontItalic(italic || quoted);
            format.setFontUnderline(underline);
            format.setFontStrikeOut(strike);
            if (kind == Mono) {
                format.setFontFamilies({m_mono});
                format.setFontFixedPitch(true);
            }
            return format;
        };
        if (first)
            cursor.setBlockFormat(block);
        else
            cursor.insertBlock(block);
        first = false;
        if (!mark.isEmpty())
            cursor.insertText(mark, dressed(false, false, false, false));
        const QVariantList runs = paragraph.value(QStringLiteral("runs")).toList();
        for (const QVariant &each : runs) {
            const QVariantMap run = each.toMap();
            cursor.insertText(run.value(QStringLiteral("text")).toString(),
                              dressed(run.value(QStringLiteral("bold")).toBool(), run.value(QStringLiteral("italic")).toBool(),
                                      run.value(QStringLiteral("underline")).toBool(), run.value(QStringLiteral("strike")).toBool()));
        }
    }
    paper.print(&writer);
    return true;
}
