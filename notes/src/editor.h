#pragma once

#include <QObject>
#include <QPointer>
#include <QQuickTextDocument>
#include <QTextBlock>
#include <QTextBlockFormat>
#include <QTextCharFormat>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include <functional>

class QTextDocument;

// The window's hands on a note's text: the QML TextEdit shows and edits
// the document, this keeps it a note. Every paragraph is of one kind (a
// title, a heading, a subheading, body text, monostyled, or an item of a
// bulleted, dashed, numbered or check list), may be quoted, and a list's
// item stands at a level; the kind decides the paragraph's type and inset,
// and whatever comes into the document any other way (typing after a
// heading, a paste) is dressed to match once the change is done. The marks
// before list items and the bar beside a quote are not in the document:
// `markers` says where each belongs and the window draws them. It turns
// the document into notes.mjs's paragraphs and back, copies and pastes
// them whole, and prints a note to a PDF. Sizes are in the window's
// pixels.
class Editor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QQuickTextDocument *document READ document WRITE setDocument NOTIFY documentChanged)
    // Where the TextEdit's cursor and selection are (bound from it).
    Q_PROPERTY(int cursorPosition READ cursorPosition WRITE setCursorPosition NOTIFY selectionChanged)
    Q_PROPERTY(int selectionStart READ selectionStart WRITE setSelectionStart NOTIFY selectionChanged)
    Q_PROPERTY(int selectionEnd READ selectionEnd WRITE setSelectionEnd NOTIFY selectionChanged)
    // The family monostyled text is set in.
    Q_PROPERTY(QString monoFamily READ monoFamily WRITE setMonoFamily NOTIFY monoFamilyChanged)
    // At the cursor, or where the selection begins: the characters' marks,
    // the paragraph's kind (notes.mjs's names), whether it is quoted and,
    // a checklist's item, checked.
    Q_PROPERTY(bool bold READ bold NOTIFY formatChanged)
    Q_PROPERTY(bool italic READ italic NOTIFY formatChanged)
    Q_PROPERTY(bool underline READ underline NOTIFY formatChanged)
    Q_PROPERTY(bool strike READ strike NOTIFY formatChanged)
    Q_PROPERTY(QString kind READ kind NOTIFY formatChanged)
    Q_PROPERTY(bool quote READ quote NOTIFY formatChanged)
    Q_PROPERTY(bool checked READ checked NOTIFY formatChanged)
    // What is drawn beside the text: for each list item and quoted
    // paragraph { kind, level, checked, number, quote, start, last, x }
    // (its first and last places in the document; where its text begins).
    Q_PROPERTY(QVariantList markers READ markers NOTIFY markersChanged)

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
    QString monoFamily() const { return m_mono; }
    void setMonoFamily(const QString &family);

    bool bold() const;
    bool italic() const;
    bool underline() const;
    bool strike() const;
    QString kind() const;
    bool quote() const;
    bool checked() const;
    QVariantList markers() const { return m_markers; }

    // The note as notes.mjs's paragraphs, and from them (which empties the
    // undo history; `edited` is not told).
    Q_INVOKABLE QVariantList paragraphs() const;
    Q_INVOKABLE void setParagraphs(const QVariantList &paragraphs);

    Q_INVOKABLE void setBold(bool on);
    Q_INVOKABLE void setItalic(bool on);
    Q_INVOKABLE void setUnderline(bool on);
    Q_INVOKABLE void setStrike(bool on);
    // The selection's paragraphs take a kind; a list's kind chosen where
    // every one has it already turns them back to body text.
    Q_INVOKABLE void setKind(const QString &kind);
    Q_INVOKABLE void setQuote(bool on);
    // The selection's checklist items; the one at a place (its mark was
    // clicked).
    Q_INVOKABLE void setChecked(bool on);
    Q_INVOKABLE void toggleChecked(int position);
    // List items a level in or out. False: none was selected.
    Q_INVOKABLE bool indent(int by);
    // Keys the TextEdit would get wrong for a note. False: nothing of the
    // kind to do, the key is the TextEdit's. Return ends a list in an
    // empty item, and after a heading comes body text; Backspace at an
    // item's start takes its mark away.
    Q_INVOKABLE bool returnKey();
    Q_INVOKABLE bool backspaceKey();

    // The clipboard: paragraphs whole between notes, text to and from
    // anything else.
    Q_INVOKABLE void copy();
    Q_INVOKABLE void cut();
    Q_INVOKABLE void paste();
    // The note on paper, as a PDF.
    Q_INVOKABLE bool exportPdf(const QUrl &file, const QString &title) const;

Q_SIGNALS:
    void documentChanged();
    void selectionChanged();
    void monoFamilyChanged();
    void formatChanged();
    void markersChanged();
    // The note was changed by hand (not by setParagraphs).
    void edited();

private:
    struct Marks {
        bool bold = false, italic = false, underline = false, strike = false;
    };
    QTextDocument *text_() const;
    QTextCharFormat charFormat() const;
    QTextBlock block_() const;
    QTextCharFormat dress(int kind, const Marks &marks) const;
    QTextBlockFormat shape(int kind, int level, bool checked, bool quote) const;
    void changeChars(const std::function<void(Marks &)> &change);
    void changeBlocks(const std::function<void(int &kind, int &level, bool &checked, bool &quote)> &change);
    void redress(const QTextBlock &block, int kind);
    bool tidy(const QTextBlock &block);
    void contentsChanged(int position, int removed, int added);
    void settle();
    void moved();
    void remark();
    QVariantList taken(int from, int to) const;
    void put(QTextCursor &cursor, const QVariantList &paragraphs);

    QPointer<QQuickTextDocument> m_document;
    QPointer<QTextDocument> m_connected;
    QString m_mono = QStringLiteral("monospace");
    int m_cursor = 0;
    int m_start = 0;
    int m_end = 0;
    // What will be typed at the cursor when a mark was chosen with nothing
    // selected: the next characters put there take it.
    QTextCharFormat m_pending;
    int m_pendingAt = -1;
    QTextCharFormat m_typed;
    int m_typedAt = -1;
    // The stretch of the document a change touched, for settle(), and how
    // much it added.
    int m_touchedFrom = -1;
    int m_touchedTo = -1;
    int m_added = 0;
    bool m_settling = false;
    bool m_loading = false;
    QVariantList m_markers;
    QTimer m_changed;
    QTimer m_told;
};
