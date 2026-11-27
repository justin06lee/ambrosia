#pragma once

#include <QColor>
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QQuickTextDocument>
#include <QTextBlockFormat>
#include <QTextCharFormat>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include <functional>

class QTextDocument;

// A window's hands on its text: the QML TextEdit shows and edits the
// document, this reads and changes what QML can't reach. It says what the
// format is where the cursor stands (for the format bar and the ruler),
// changes the selection's characters and paragraphs, turns the document
// into rtf.mjs's model and back, finds and replaces, and prints to a PDF.
// Sizes are in points, which here are the window's pixels (main.cpp).
class Editor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY documentChanged)
    // Where the TextEdit's cursor and selection are (bound from it).
    Q_PROPERTY(int cursorPosition READ cursorPosition WRITE setCursorPosition NOTIFY selectionChanged)
    Q_PROPERTY(int selectionStart READ selectionStart WRITE setSelectionStart NOTIFY selectionChanged)
    Q_PROPERTY(int selectionEnd READ selectionEnd WRITE setSelectionEnd NOTIFY selectionChanged)
    Q_PROPERTY(bool modified READ modified WRITE setModified NOTIFY modifiedChanged)
    // The window is dark: the document's colors show with their lightness
    // turned over, hue kept, as a Mac's TextEdit shows them in Dark (black
    // text white, a pale highlight a deep one under it). The document here
    // holds the colors as shown; the model, and so the file, the true ones.
    Q_PROPERTY(bool dark READ dark WRITE setDark NOTIFY darkChanged)
    Q_PROPERTY(bool empty READ empty NOTIFY formatChanged)
    // The characters' format at the cursor, or where the selection begins.
    Q_PROPERTY(bool bold READ bold NOTIFY formatChanged)
    Q_PROPERTY(bool italic READ italic NOTIFY formatChanged)
    Q_PROPERTY(bool underline READ underline NOTIFY formatChanged)
    Q_PROPERTY(bool strike READ strike NOTIFY formatChanged)
    Q_PROPERTY(QString family READ family NOTIFY formatChanged)
    Q_PROPERTY(int weight READ weight NOTIFY formatChanged)
    Q_PROPERTY(qreal size READ size NOTIFY formatChanged)
    // Not valid: the text's own color, no highlight.
    Q_PROPERTY(QColor color READ color NOTIFY formatChanged)
    Q_PROPERTY(QColor highlight READ highlight NOTIFY formatChanged)
    // The paragraph's: "left", "center", "right" or "justify"; the list's
    // marker (rtf.mjs's names) or nothing; line height, 1 being single;
    // indents from the text's left and right edges, the first line's from
    // the left indent; tab stops from the left edge.
    Q_PROPERTY(QString alignment READ alignment NOTIFY formatChanged)
    Q_PROPERTY(QString listMarker READ listMarker NOTIFY formatChanged)
    Q_PROPERTY(qreal spacing READ spacing NOTIFY formatChanged)
    Q_PROPERTY(qreal leftIndent READ leftIndent NOTIFY formatChanged)
    Q_PROPERTY(qreal firstIndent READ firstIndent NOTIFY formatChanged)
    Q_PROPERTY(qreal rightIndent READ rightIndent NOTIFY formatChanged)
    Q_PROPERTY(QVariantList tabs READ tabs NOTIFY formatChanged)

public:
    explicit Editor(QObject *parent = nullptr);

    QQuickTextDocument *document() const { return m_document; }
    void setDocument(QQuickTextDocument *document);
    int cursorPosition() const { return m_cursor; }
    void setCursorPosition(int position);
    int selectionStart() const { return m_start; }
    void setSelectionStart(int position);
    int selectionEnd() const { return m_end; }
    void setSelectionEnd(int position);
    bool modified() const;
    void setModified(bool modified);
    bool empty() const;
    bool dark() const { return m_dark; }
    void setDark(bool dark);

    bool bold() const;
    bool italic() const;
    bool underline() const;
    bool strike() const;
    QString family() const;
    int weight() const;
    qreal size() const;
    QColor color() const;
    QColor highlight() const;
    QString alignment() const;
    QString listMarker() const;
    qreal spacing() const;
    qreal leftIndent() const;
    qreal firstIndent() const;
    qreal rightIndent() const;
    QVariantList tabs() const;

    // The whole document as rtf.mjs's model, and from one (which empties
    // the undo history and leaves it unmodified).
    Q_INVOKABLE QVariantMap model() const;
    Q_INVOKABLE void setModel(const QVariantMap &model);
    // The text alone, and a plain document from text.
    Q_INVOKABLE QString text() const;
    Q_INVOKABLE void setText(const QString &text);
    // A new rich document's paragraph: Cocoa's twelve tab stops, 28 apart.
    Q_INVOKABLE void startRich();

    Q_INVOKABLE void setBold(bool on);
    Q_INVOKABLE void setItalic(bool on);
    Q_INVOKABLE void setUnderline(bool on);
    Q_INVOKABLE void setStrike(bool on);
    Q_INVOKABLE void setFamily(const QString &family);
    Q_INVOKABLE void setStyle(int weight, bool italic);
    Q_INVOKABLE void setSize(qreal size);
    // Each run a point (or `by`) larger than it is.
    Q_INVOKABLE void bigger(qreal by);
    // By name ("#rrggbb"), the true color; nothing for the text's own
    // color, no highlight. storedName: a shown color's true one.
    Q_INVOKABLE QString storedName(const QColor &shown) const;
    Q_INVOKABLE void setColor(const QString &name);
    Q_INVOKABLE void setHighlight(const QString &name);
    Q_INVOKABLE void setAlignment(const QString &alignment);
    Q_INVOKABLE void setSpacing(qreal spacing);
    Q_INVOKABLE void setList(const QString &marker);
    Q_INVOKABLE void setIndents(qreal left, qreal first, qreal right);
    Q_INVOKABLE void setTabs(const QVariantList &tabs);
    // Return in an empty list item ends the list; Tab and Shift-Tab in an
    // item move it a level in or out. False when there was nothing of the
    // kind to do and the key is the TextEdit's.
    Q_INVOKABLE bool returnInList();
    Q_INVOKABLE bool indentList(int by);

    // Where `what` next is from a place, going round the end: { start,
    // end }, or nothing. How many there are. Replacing one, or all.
    Q_INVOKABLE QVariantMap find(const QString &what, int from, bool backward) const;
    Q_INVOKABLE int count(const QString &what) const;
    Q_INVOKABLE void replace(int start, int end, const QString &with);
    Q_INVOKABLE int replaceAll(const QString &what, const QString &with);
    // The document on paper, as a PDF.
    Q_INVOKABLE bool exportPdf(const QUrl &file, const QString &title) const;

Q_SIGNALS:
    void documentChanged();
    void selectionChanged();
    void modifiedChanged();
    void darkChanged();
    void formatChanged();

private:
    QTextDocument *text_() const;
    QTextCharFormat charFormat() const;
    QTextBlockFormat blockFormat() const;
    void changeChars(const std::function<void(QTextCharFormat &)> &change);
    void changeBlocks(const std::function<void(QTextBlockFormat &)> &change);
    void contentsChanged(int position, int removed, int added);
    void settle();
    void moved();
    QColor shown(const QColor &stored);
    QColor stored(const QColor &shown) const;
    QTextCharFormat dressed(QTextCharFormat format);
    void recolor(bool dark);

    QPointer<QQuickTextDocument> m_document;
    QPointer<QTextDocument> m_connected;
    int m_cursor = 0;
    int m_start = 0;
    int m_end = 0;
    // What will be typed at the cursor when a format was chosen with
    // nothing selected: the next characters put there take it.
    QTextCharFormat m_pending;
    int m_pendingAt = -1;
    // What settle() has to see to once the TextEdit's own change is done:
    // text typed at m_typedAt that takes m_typed, and the stretch of the
    // document that changed.
    QTextCharFormat m_typed;
    int m_typedAt = -1;
    int m_touchedFrom = -1;
    int m_touchedTo = -1;
    bool m_settling = false;
    bool m_loading = false;
    bool m_dark = false;
    // In Dark: each shown color's true one, where it came from a file or a
    // well, so that writing gives back exactly what was read.
    QHash<QRgb, QRgb> m_trueColors;
    QTimer m_changed;
};
