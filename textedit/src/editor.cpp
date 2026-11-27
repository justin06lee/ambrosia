#include "editor.h"

#include <QFont>
#include <QLocale>
#include <QPageLayout>
#include <QPageSize>
#include <QPdfWriter>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextDocument>
#include <QTextList>

#include <memory>

namespace
{
const struct {
    const char *name;
    QTextListFormat::Style style;
} listStyles[] = {
    {"disc", QTextListFormat::ListDisc},
    {"circle", QTextListFormat::ListCircle},
    {"square", QTextListFormat::ListSquare},
    {"decimal", QTextListFormat::ListDecimal},
    {"lower-alpha", QTextListFormat::ListLowerAlpha},
    {"upper-alpha", QTextListFormat::ListUpperAlpha},
    {"lower-roman", QTextListFormat::ListLowerRoman},
    {"upper-roman", QTextListFormat::ListUpperRoman},
};

QTextListFormat::Style styleOf(const QString &marker)
{
    for (const auto &entry : listStyles) {
        if (marker == QLatin1String(entry.name))
            return entry.style;
    }
    return QTextListFormat::ListDisc;
}

QString markerOf(QTextListFormat::Style style)
{
    for (const auto &entry : listStyles) {
        if (style == entry.style)
            return QString::fromLatin1(entry.name);
    }
    return QStringLiteral("disc");
}

QString alignmentName(Qt::Alignment alignment)
{
    if (alignment & Qt::AlignHCenter)
        return QStringLiteral("center");
    if (alignment & Qt::AlignRight)
        return QStringLiteral("right");
    if (alignment & Qt::AlignJustify)
        return QStringLiteral("justify");
    return QStringLiteral("left");
}

Qt::Alignment alignmentOf(const QString &name)
{
    if (name == QLatin1String("center"))
        return Qt::AlignHCenter;
    if (name == QLatin1String("right"))
        return Qt::AlignRight | Qt::AlignAbsolute;
    if (name == QLatin1String("justify"))
        return Qt::AlignJustify;
    return Qt::AlignLeft | Qt::AlignAbsolute;
}

bool isBold(const QTextCharFormat &format)
{
    return format.fontWeight() >= QFont::DemiBold;
}

QString familyOf(const QTextCharFormat &format, const QTextDocument *document)
{
    const QStringList families = format.fontFamilies().toStringList();
    return families.isEmpty() ? document->defaultFont().family() : families.first();
}

qreal sizeOf(const QTextCharFormat &format, const QTextDocument *document)
{
    const qreal size = format.fontPointSize();
    return size > 0 ? size : document->defaultFont().pointSizeF();
}

QVariantMap runOf(const QString &text, const QTextCharFormat &format, const QTextDocument *document)
{
    const auto script = format.verticalAlignment();
    return {
        {QStringLiteral("text"), text},
        {QStringLiteral("family"), familyOf(format, document)},
        {QStringLiteral("size"), sizeOf(format, document)},
        {QStringLiteral("bold"), isBold(format)},
        {QStringLiteral("italic"), format.fontItalic()},
        {QStringLiteral("underline"), format.fontUnderline()},
        {QStringLiteral("strike"), format.fontStrikeOut()},
        {QStringLiteral("color"), format.hasProperty(QTextFormat::ForegroundBrush) ? format.foreground().color().name() : QString()},
        {QStringLiteral("background"), format.hasProperty(QTextFormat::BackgroundBrush) ? format.background().color().name() : QString()},
        {QStringLiteral("script"), script == QTextCharFormat::AlignSuperScript ? QStringLiteral("super")
                                   : script == QTextCharFormat::AlignSubScript ? QStringLiteral("sub") : QString()},
    };
}

QTextCharFormat formatOf(const QVariantMap &run)
{
    QTextCharFormat format;
    const QString family = run.value(QStringLiteral("family")).toString();
    if (!family.isEmpty())
        format.setFontFamilies({family});
    const qreal size = run.value(QStringLiteral("size")).toDouble();
    if (size > 0)
        format.setFontPointSize(size);
    format.setFontWeight(run.value(QStringLiteral("bold")).toBool() ? QFont::Bold : QFont::Normal);
    format.setFontItalic(run.value(QStringLiteral("italic")).toBool());
    format.setFontUnderline(run.value(QStringLiteral("underline")).toBool());
    format.setFontStrikeOut(run.value(QStringLiteral("strike")).toBool());
    const QColor color(run.value(QStringLiteral("color")).toString());
    if (color.isValid())
        format.setForeground(color);
    const QColor background(run.value(QStringLiteral("background")).toString());
    if (background.isValid())
        format.setBackground(background);
    const QString script = run.value(QStringLiteral("script")).toString();
    if (script == QLatin1String("super"))
        format.setVerticalAlignment(QTextCharFormat::AlignSuperScript);
    else if (script == QLatin1String("sub"))
        format.setVerticalAlignment(QTextCharFormat::AlignSubScript);
    return format;
}

QList<QTextOption::Tab> tabsOf(const QVariantList &positions)
{
    QList<QTextOption::Tab> tabs;
    for (const QVariant &position : positions)
        tabs.append(QTextOption::Tab(position.toDouble(), QTextOption::LeftTab));
    return tabs;
}

void setLineHeight(QTextBlockFormat &format, qreal spacing)
{
    if (qAbs(spacing - 1) < 0.005)
        format.setLineHeight(0, QTextBlockFormat::SingleHeight);
    else
        format.setLineHeight(spacing * 100, QTextBlockFormat::ProportionalHeight);
}

qreal lineHeightOf(const QTextBlockFormat &format)
{
    return format.lineHeightType() == QTextBlockFormat::ProportionalHeight && format.lineHeight() > 0 ? format.lineHeight() / 100 : 1;
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
    if (m_connected) {
        connect(m_connected, &QTextDocument::contentsChange, this, &Editor::contentsChanged);
        connect(m_connected, &QTextDocument::modificationChanged, this, &Editor::modifiedChanged);
    }
    Q_EMIT documentChanged();
    Q_EMIT modifiedChanged();
    m_changed.start();
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

bool Editor::modified() const
{
    const QTextDocument *document = text_();
    return document && document->isModified();
}

void Editor::setModified(bool modified)
{
    if (QTextDocument *document = text_())
        document->setModified(modified);
}

bool Editor::empty() const
{
    const QTextDocument *document = text_();
    return !document || document->isEmpty();
}

void Editor::contentsChanged(int position, int, int added)
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
    if (!m_settling) {
        m_settling = true;
        QMetaObject::invokeMethod(this, &Editor::settle, Qt::QueuedConnection);
    }
    m_changed.start();
}

// After a change of the TextEdit's own, as one step with it for Undo:
// what was just typed takes the format chosen for it; and no paragraph
// keeps a highlight as its own character format, which Qt Quick would
// paint across the whole paragraph (Return typed in highlighted text
// leaves one).
void Editor::settle()
{
    m_settling = false;
    QTextDocument *document = text_();
    const int from = m_touchedFrom, to = m_touchedTo, typedAt = m_typedAt;
    m_touchedFrom = m_touchedTo = m_typedAt = -1;
    if (!document || from < 0)
        return;
    m_loading = true;
    QTextCursor cursor(document);
    bool joined = false;
    const auto join = [&] {
        if (!joined)
            cursor.joinPreviousEditBlock();
        joined = true;
    };
    if (typedAt >= 0 && m_cursor > typedAt && m_cursor <= document->characterCount() - 1) {
        join();
        cursor.setPosition(typedAt);
        cursor.setPosition(m_cursor, QTextCursor::KeepAnchor);
        cursor.setCharFormat(m_typed);
    }
    for (QTextBlock block = document->findBlock(from); block.isValid() && block.position() <= to; block = block.next()) {
        QTextCharFormat format = block.charFormat();
        if (!format.hasProperty(QTextFormat::BackgroundBrush))
            continue;
        join();
        format.clearProperty(QTextFormat::BackgroundBrush);
        QTextCursor(block).setBlockCharFormat(format);
    }
    if (joined)
        cursor.endEditBlock();
    m_loading = false;
    m_changed.start();
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

QTextBlockFormat Editor::blockFormat() const
{
    QTextDocument *document = text_();
    if (!document)
        return {};
    return document->findBlock(m_start != m_end ? m_start : m_cursor).blockFormat();
}

bool Editor::bold() const { return isBold(charFormat()); }
bool Editor::italic() const { return charFormat().fontItalic(); }
bool Editor::underline() const { return charFormat().fontUnderline(); }
bool Editor::strike() const { return charFormat().fontStrikeOut(); }
int Editor::weight() const { return charFormat().fontWeight(); }

QString Editor::family() const
{
    const QTextDocument *document = text_();
    return document ? familyOf(charFormat(), document) : QString();
}

qreal Editor::size() const
{
    const QTextDocument *document = text_();
    return document ? sizeOf(charFormat(), document) : 0;
}

QColor Editor::color() const
{
    const QTextCharFormat format = charFormat();
    return format.hasProperty(QTextFormat::ForegroundBrush) ? format.foreground().color() : QColor();
}

QColor Editor::highlight() const
{
    const QTextCharFormat format = charFormat();
    return format.hasProperty(QTextFormat::BackgroundBrush) ? format.background().color() : QColor();
}

QString Editor::alignment() const { return alignmentName(blockFormat().alignment()); }
qreal Editor::spacing() const { return lineHeightOf(blockFormat()); }
qreal Editor::leftIndent() const { return blockFormat().leftMargin(); }
qreal Editor::firstIndent() const { return blockFormat().textIndent(); }
qreal Editor::rightIndent() const { return blockFormat().rightMargin(); }

QString Editor::listMarker() const
{
    const QTextDocument *document = text_();
    if (!document)
        return {};
    const QTextList *list = document->findBlock(m_start != m_end ? m_start : m_cursor).textList();
    return list ? markerOf(list->format().style()) : QString();
}

QVariantList Editor::tabs() const
{
    QVariantList positions;
    const QList<QTextOption::Tab> tabs = blockFormat().tabPositions();
    for (const QTextOption::Tab &tab : tabs)
        positions << tab.position;
    return positions;
}

void Editor::changeChars(const std::function<void(QTextCharFormat &)> &change)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    if (m_start == m_end) {
        QTextCharFormat format = charFormat();
        change(format);
        m_pending = format;
        m_pendingAt = m_cursor;
        // An empty paragraph takes it as its own: what is typed there
        // gets its format from the paragraph.
        const QTextBlock block = document->findBlock(m_cursor);
        if (block.isValid() && block.length() <= 1) {
            QTextCharFormat own = format;
            own.clearProperty(QTextFormat::BackgroundBrush);
            m_loading = true;
            QTextCursor(block).setBlockCharFormat(own);
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
    QList<QTextBlock> bare;
    for (QTextBlock block = document->findBlock(m_start); block.isValid() && block.position() < m_end; block = block.next()) {
        if (block.length() <= 1)
            bare.append(block);
        for (auto it = block.begin(); !it.atEnd(); ++it) {
            const QTextFragment fragment = it.fragment();
            const int from = qMax(fragment.position(), m_start), to = qMin(fragment.position() + fragment.length(), m_end);
            if (from >= to)
                continue;
            QTextCharFormat format = fragment.charFormat();
            change(format);
            pieces.append({from, to, format});
        }
    }
    QTextCursor cursor(document);
    cursor.beginEditBlock();
    for (const Piece &piece : std::as_const(pieces)) {
        cursor.setPosition(piece.from);
        cursor.setPosition(piece.to, QTextCursor::KeepAnchor);
        cursor.setCharFormat(piece.format);
    }
    for (const QTextBlock &block : std::as_const(bare)) {
        QTextCharFormat format = block.charFormat();
        change(format);
        format.clearProperty(QTextFormat::BackgroundBrush);
        QTextCursor(block).setBlockCharFormat(format);
    }
    cursor.endEditBlock();
    m_changed.start();
}

void Editor::changeBlocks(const std::function<void(QTextBlockFormat &)> &change)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    const int from = m_start != m_end ? m_start : m_cursor;
    // A selection that ends where a paragraph begins doesn't take it in.
    const int to = m_start != m_end ? m_end - 1 : m_cursor;
    QTextCursor cursor(document);
    cursor.beginEditBlock();
    for (QTextBlock block = document->findBlock(from); block.isValid() && block.position() <= to; block = block.next()) {
        QTextBlockFormat format = block.blockFormat();
        change(format);
        QTextCursor(block).setBlockFormat(format);
    }
    cursor.endEditBlock();
    m_changed.start();
}

void Editor::setBold(bool on)
{
    changeChars([on](QTextCharFormat &format) { format.setFontWeight(on ? QFont::Bold : QFont::Normal); });
}

void Editor::setItalic(bool on)
{
    changeChars([on](QTextCharFormat &format) { format.setFontItalic(on); });
}

void Editor::setUnderline(bool on)
{
    changeChars([on](QTextCharFormat &format) { format.setFontUnderline(on); });
}

void Editor::setStrike(bool on)
{
    changeChars([on](QTextCharFormat &format) { format.setFontStrikeOut(on); });
}

void Editor::setFamily(const QString &family)
{
    changeChars([&family](QTextCharFormat &format) { format.setFontFamilies({family}); });
}

void Editor::setStyle(int weight, bool italic)
{
    changeChars([weight, italic](QTextCharFormat &format) {
        format.setFontWeight(weight);
        format.setFontItalic(italic);
    });
}

void Editor::setSize(qreal size)
{
    if (size < 1 || size > 2000)
        return;
    changeChars([size](QTextCharFormat &format) { format.setFontPointSize(size); });
}

void Editor::bigger(qreal by)
{
    const QTextDocument *document = text_();
    if (!document)
        return;
    changeChars([by, document](QTextCharFormat &format) { format.setFontPointSize(qMax(1.0, sizeOf(format, document) + by)); });
}

void Editor::setColor(const QString &name)
{
    const QColor color = name.isEmpty() ? QColor() : QColor(name);
    changeChars([&color](QTextCharFormat &format) {
        if (color.isValid())
            format.setForeground(color);
        else
            format.clearProperty(QTextFormat::ForegroundBrush);
    });
}

void Editor::setHighlight(const QString &name)
{
    const QColor color = name.isEmpty() ? QColor() : QColor(name);
    changeChars([&color](QTextCharFormat &format) {
        if (color.isValid())
            format.setBackground(color);
        else
            format.clearProperty(QTextFormat::BackgroundBrush);
    });
}

void Editor::setAlignment(const QString &alignment)
{
    changeBlocks([&alignment](QTextBlockFormat &format) { format.setAlignment(alignmentOf(alignment)); });
}

void Editor::setSpacing(qreal spacing)
{
    if (spacing < 0.5 || spacing > 10)
        return;
    changeBlocks([spacing](QTextBlockFormat &format) { setLineHeight(format, spacing); });
}

void Editor::setIndents(qreal left, qreal first, qreal right)
{
    changeBlocks([=](QTextBlockFormat &format) {
        format.setLeftMargin(qMax(0.0, left));
        format.setTextIndent(qMax(-qMax(0.0, left), first));
        format.setRightMargin(qMax(0.0, right));
    });
}

void Editor::setTabs(const QVariantList &tabs)
{
    QVariantList sorted = tabs;
    std::sort(sorted.begin(), sorted.end(), [](const QVariant &a, const QVariant &b) { return a.toDouble() < b.toDouble(); });
    changeBlocks([&sorted](QTextBlockFormat &format) { format.setTabPositions(tabsOf(sorted)); });
}

void Editor::setList(const QString &marker)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    const int from = m_start != m_end ? m_start : m_cursor;
    const int to = m_start != m_end ? m_end - 1 : m_cursor;
    QTextCursor cursor(document);
    cursor.beginEditBlock();
    if (marker.isEmpty()) {
        for (QTextBlock block = document->findBlock(from); block.isValid() && block.position() <= to; block = block.next()) {
            if (QTextList *list = block.textList()) {
                list->remove(block);
                QTextBlockFormat format = block.blockFormat();
                format.setIndent(0);
                QTextCursor(block).setBlockFormat(format);
            }
        }
    } else if (QTextList *list = document->findBlock(from).textList()) {
        // In a list already: the whole list changes its marker.
        QTextListFormat format = list->format();
        format.setStyle(styleOf(marker));
        list->setFormat(format);
    } else {
        QTextListFormat format;
        format.setStyle(styleOf(marker));
        format.setIndent(1);
        cursor.setPosition(from);
        cursor.setPosition(to, QTextCursor::KeepAnchor);
        // The list's own inset stands in for the paragraphs' indents.
        QTextBlockFormat flat;
        flat.setLeftMargin(0);
        flat.setTextIndent(0);
        cursor.mergeBlockFormat(flat);
        cursor.createList(format);
    }
    cursor.endEditBlock();
    m_changed.start();
}

bool Editor::returnInList()
{
    QTextDocument *document = text_();
    if (!document || m_start != m_end)
        return false;
    const QTextBlock block = document->findBlock(m_cursor);
    QTextList *list = block.textList();
    if (!list || block.length() > 1)
        return false;
    QTextCursor cursor(block);
    cursor.beginEditBlock();
    list->remove(block);
    QTextBlockFormat format = block.blockFormat();
    format.setIndent(0);
    cursor.setBlockFormat(format);
    cursor.endEditBlock();
    m_changed.start();
    return true;
}

bool Editor::indentList(int by)
{
    QTextDocument *document = text_();
    if (!document)
        return false;
    const int from = m_start != m_end ? m_start : m_cursor;
    const int to = m_start != m_end ? m_end - 1 : m_cursor;
    if (!document->findBlock(from).textList())
        return false;
    QTextCursor cursor(document);
    cursor.beginEditBlock();
    for (QTextBlock block = document->findBlock(from); block.isValid() && block.position() <= to; block = block.next()) {
        QTextList *list = block.textList();
        if (!list)
            continue;
        const int level = list->format().indent() + by;
        if (level < 1 || level > 9)
            continue;
        // Into the list at that level next to it, if there is one.
        QTextList *beside = nullptr;
        for (const QTextBlock &near : {block.previous(), block.next()}) {
            QTextList *other = near.isValid() ? near.textList() : nullptr;
            if (other && other != list && other->format().indent() == level) {
                beside = other;
                break;
            }
        }
        if (beside) {
            beside->add(block);
        } else {
            QTextListFormat format = list->format();
            format.setIndent(level);
            QTextCursor(block).createList(format);
        }
    }
    cursor.endEditBlock();
    m_changed.start();
    return true;
}

QVariantMap Editor::model() const
{
    const QTextDocument *document = text_();
    QVariantList paragraphs;
    if (!document)
        return {};
    QHash<const QTextList *, int> ids;
    int lastId = 0, nextId = 1;
    for (QTextBlock block = document->begin(); block.isValid(); block = block.next()) {
        const QTextBlockFormat format = block.blockFormat();
        QVariantMap paragraph{
            {QStringLiteral("align"), alignmentName(format.alignment())},
            {QStringLiteral("left"), format.leftMargin()},
            {QStringLiteral("first"), format.textIndent()},
            {QStringLiteral("right"), format.rightMargin()},
            {QStringLiteral("before"), format.topMargin()},
            {QStringLiteral("after"), format.bottomMargin()},
            {QStringLiteral("spacing"), lineHeightOf(format)},
        };
        QVariantList tabs;
        const QList<QTextOption::Tab> positions = format.tabPositions();
        for (const QTextOption::Tab &tab : positions)
            tabs << tab.position;
        if (const QTextList *list = block.textList()) {
            const int level = qMax(0, list->format().indent() - 1);
            // A list nested in another is one more level of the same
            // list in RTF; here each level is a list of its own.
            if (!ids.contains(list))
                ids.insert(list, level > 0 && lastId > 0 ? lastId : nextId++);
            lastId = ids.value(list);
            paragraph[QStringLiteral("list")] = QVariantMap{{QStringLiteral("marker"), markerOf(list->format().style())},
                                                            {QStringLiteral("level"), level}, {QStringLiteral("id"), lastId}};
            paragraph[QStringLiteral("left")] = 0;
            paragraph[QStringLiteral("first")] = 0;
            tabs.clear();
        } else {
            paragraph[QStringLiteral("list")] = QVariant::fromValue(nullptr);
            lastId = 0;
        }
        paragraph[QStringLiteral("tabs")] = tabs;
        QVariantList runs;
        for (auto it = block.begin(); !it.atEnd(); ++it) {
            const QTextFragment fragment = it.fragment();
            if (!fragment.isValid())
                continue;
            // Not the marks pictures stand on: they aren't kept.
            QString text = fragment.text();
            text.remove(QChar::ObjectReplacementCharacter);
            if (!text.isEmpty())
                runs << runOf(text, fragment.charFormat(), document);
        }
        if (runs.isEmpty())
            runs << runOf(QString(), block.charFormat(), document);
        paragraph[QStringLiteral("runs")] = runs;
        paragraphs << paragraph;
    }
    return {{QStringLiteral("paragraphs"), paragraphs}};
}

void Editor::setModel(const QVariantMap &model)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    m_loading = true;
    m_pendingAt = -1;
    document->setUndoRedoEnabled(false);
    document->clear();
    QTextCursor cursor(document);
    cursor.beginEditBlock();
    QHash<QPair<int, int>, QPointer<QTextList>> lists;
    bool first = true;
    const QVariantList paragraphs = model.value(QStringLiteral("paragraphs")).toList();
    for (const QVariant &entry : paragraphs) {
        const QVariantMap paragraph = entry.toMap();
        QTextBlockFormat format;
        format.setAlignment(alignmentOf(paragraph.value(QStringLiteral("align")).toString()));
        format.setLeftMargin(paragraph.value(QStringLiteral("left")).toDouble());
        format.setTextIndent(paragraph.value(QStringLiteral("first")).toDouble());
        format.setRightMargin(paragraph.value(QStringLiteral("right")).toDouble());
        format.setTopMargin(paragraph.value(QStringLiteral("before")).toDouble());
        format.setBottomMargin(paragraph.value(QStringLiteral("after")).toDouble());
        setLineHeight(format, paragraph.value(QStringLiteral("spacing"), 1.0).toDouble());
        format.setTabPositions(tabsOf(paragraph.value(QStringLiteral("tabs")).toList()));
        const QVariantList runs = paragraph.value(QStringLiteral("runs")).toList();
        // (A paragraph's own character format without the highlight:
        // see settle().)
        QTextCharFormat opening = runs.isEmpty() ? QTextCharFormat() : formatOf(runs.first().toMap());
        opening.clearProperty(QTextFormat::BackgroundBrush);
        if (first) {
            cursor.setBlockFormat(format);
            cursor.setBlockCharFormat(opening);
        } else {
            cursor.insertBlock(format, opening);
        }
        first = false;
        for (const QVariant &item : runs) {
            const QVariantMap run = item.toMap();
            const QString text = run.value(QStringLiteral("text")).toString();
            if (!text.isEmpty())
                cursor.insertText(text, formatOf(run));
        }
        const QVariantMap list = paragraph.value(QStringLiteral("list")).toMap();
        if (!list.isEmpty()) {
            const int id = list.value(QStringLiteral("id")).toInt(), level = list.value(QStringLiteral("level")).toInt();
            // An item ends the lists nested deeper than it: the next
            // nest begins its numbers again.
            for (auto it = lists.begin(); it != lists.end();) {
                if (it.key().first == id && it.key().second > level)
                    it = lists.erase(it);
                else
                    ++it;
            }
            QPointer<QTextList> &into = lists[{id, level}];
            if (into) {
                into->add(cursor.block());
            } else {
                QTextListFormat listFormat;
                listFormat.setStyle(styleOf(list.value(QStringLiteral("marker")).toString()));
                listFormat.setIndent(level + 1);
                into = cursor.createList(listFormat);
            }
        }
    }
    cursor.endEditBlock();
    document->setUndoRedoEnabled(true);
    document->setModified(false);
    m_loading = false;
    m_changed.start();
}

QString Editor::text() const
{
    const QTextDocument *document = text_();
    return document ? document->toPlainText() : QString();
}

void Editor::setText(const QString &text)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    m_loading = true;
    m_pendingAt = -1;
    document->setUndoRedoEnabled(false);
    document->setPlainText(text);
    document->setUndoRedoEnabled(true);
    document->setModified(false);
    m_loading = false;
    m_changed.start();
}

void Editor::startRich()
{
    QTextDocument *document = text_();
    if (!document)
        return;
    m_loading = true;
    document->setUndoRedoEnabled(false);
    document->clear();
    QTextBlockFormat format;
    QList<QTextOption::Tab> tabs;
    for (int i = 1; i <= 12; ++i)
        tabs.append(QTextOption::Tab(28.0 * i, QTextOption::LeftTab));
    format.setTabPositions(tabs);
    QTextCursor(document).setBlockFormat(format);
    document->setUndoRedoEnabled(true);
    document->setModified(false);
    m_loading = false;
    m_changed.start();
}

QVariantMap Editor::find(const QString &what, int from, bool backward) const
{
    QTextDocument *document = text_();
    if (!document || what.isEmpty())
        return {};
    const QTextDocument::FindFlags flags = backward ? QTextDocument::FindBackward : QTextDocument::FindFlags();
    QTextCursor found = document->find(what, from, flags);
    if (found.isNull())
        found = document->find(what, backward ? document->characterCount() - 1 : 0, flags);
    if (found.isNull())
        return {};
    return {{QStringLiteral("start"), found.selectionStart()}, {QStringLiteral("end"), found.selectionEnd()}};
}

int Editor::count(const QString &what) const
{
    QTextDocument *document = text_();
    if (!document || what.isEmpty())
        return 0;
    int count = 0;
    for (QTextCursor found = document->find(what, 0); !found.isNull(); found = document->find(what, found))
        ++count;
    return count;
}

void Editor::replace(int start, int end, const QString &with)
{
    QTextDocument *document = text_();
    if (!document)
        return;
    QTextCursor cursor(document);
    cursor.setPosition(start);
    cursor.setPosition(end, QTextCursor::KeepAnchor);
    cursor.insertText(with);
}

int Editor::replaceAll(const QString &what, const QString &with)
{
    QTextDocument *document = text_();
    if (!document || what.isEmpty())
        return 0;
    int count = 0;
    QTextCursor all(document);
    all.beginEditBlock();
    for (QTextCursor found = document->find(what, 0); !found.isNull(); found = document->find(what, found)) {
        found.insertText(with);
        ++count;
    }
    all.endEditBlock();
    return count;
}

bool Editor::exportPdf(const QUrl &file, const QString &title) const
{
    const QTextDocument *document = text_();
    if (!document)
        return false;
    QPdfWriter writer(file.toLocalFile());
    writer.setTitle(title);
    writer.setCreator(QStringLiteral("TextEdit"));
    writer.setPageSize(QPageSize(QLocale().measurementSystem() == QLocale::MetricSystem ? QPageSize::A4 : QPageSize::Letter));
    // An inch all round, as a Mac's TextEdit prints: QTextDocument::print
    // puts two centimetres of its own inside the page's margins.
    const qreal margin = 72 - 2 / 2.54 * 72;
    writer.setPageMargins(QMarginsF(margin, margin, margin, margin), QPageLayout::Point);
    const std::unique_ptr<QTextDocument> copy(document->clone());
    copy->print(&writer);
    return true;
}
