#pragma once

#include <QVariantList>
#include <QColor>
#include <QObject>
#include <QQuickImageProvider>
#include <QQuickWindow>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// What the windows can't do from QML: the system's appearance, each
// window's shadow (KWin draws it), reading and writing files, the fonts
// there are, the Open and Save panels, and files handed over by a second
// launch.
class App : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.ambrosia.TextEdit")
    Q_PROPERTY(bool dark READ dark NOTIFY appearanceChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY appearanceChanged)
    // Draw windows as the one in front (for grabs, where none is).
    Q_PROPERTY(bool active READ active CONSTANT)
    // The files asked for on the command line, as URLs.
    Q_PROPERTY(QStringList files READ files CONSTANT)
    // A new document starts as plain text (--plain).
    Q_PROPERTY(bool plain READ plain CONSTANT)
    // For grabs: open with the Find bar showing this.
    Q_PROPERTY(QString find READ find CONSTANT)
    // The font families installed, for the format bar.
    Q_PROPERTY(QStringList families READ families CONSTANT)

public:
    struct Options {
        QStringList files;
        QString appearance; // "light" or "dark" forces it
        QString grab;       // save the first window to this PNG once shown, then quit
        QString find;
        bool active = false;
        bool plain = false;
    };

    explicit App(const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);

    bool dark() const;
    QColor accent() const;
    bool active() const { return m_options.active; }
    bool plain() const { return m_options.plain; }
    QStringList files() const { return m_options.files; }
    QString find() const { return m_options.find; }
    QStringList families() const;

    Q_INVOKABLE void decorate(QQuickWindow *window, int radius);
    Q_INVOKABLE void shown(QQuickWindow *window);
    Q_INVOKABLE void activate(QQuickWindow *window);
    // The name a window shows for the file, and its kind's icon.
    Q_INVOKABLE QString name(const QUrl &file) const;
    Q_INVOKABLE QString iconName(const QUrl &file) const;
    // A file's contents: { ok, rtf, text, error }. An RTF file's text is
    // its bytes, one to a character (rtf.mjs reads them); any other file
    // is read as UTF-8 (or UTF-16 by its mark), as Latin-1 when it isn't.
    Q_INVOKABLE QVariantMap read(const QUrl &file, const QString &encoding = QString()) const;
    // Writes it whole or not at all; what went wrong, or nothing.
    // `bytes`: a character to a byte (RTF); otherwise as UTF-8.
    Q_INVOKABLE QString write(const QUrl &file, const QString &text, bool bytes, const QString &encoding = QString()) const;
    // Bytes (a character each) of a Windows code page as text; empty when
    // the page isn't known.
    Q_INVOKABLE QString decode(int codepage, const QString &bytes) const;
    // The installed family a document's font name means: itself, or the
    // one that is the same but for spaces and case ("JetBrainsMono").
    Q_INVOKABLE QString family(const QString &asked) const;
    // A family's styles ("Regular", "Bold Italic"…), and what one is:
    // { weight, italic }.
    Q_INVOKABLE QStringList styles(const QString &family) const;
    Q_INVOKABLE QVariantMap style(const QString &family, const QString &style) const;
    // The Open panel (the desktop's, through the portal): openRequested
    // with what was chosen.
    Q_INVOKABLE void chooseFiles();
    // The documents open when the session ended are open again at the
    // next login (../kit/resume.h): a window closing asks `leaving`, and
    // if the session is, has its documents kept; `takeKept` at the start
    // is the windows kept, each a list of URLs, and forgets them.
    // The name KWin keeps a document's window's place and size under
    // (../kit/placing.h): the window opens where the document's last did.
    Q_INVOKABLE QString frameFor(const QString &file) const;
    Q_INVOKABLE bool leaving() const;
    Q_INVOKABLE void keep(const QStringList &files) const;
    Q_INVOKABLE QVariantList takeKept() const;

    // A URL for each argument: a path (taken from the folder the app was
    // started in) or a URL already.
    static QStringList urls(const QStringList &arguments);

public Q_SLOTS:
    // A second launch hands its files (and its activation token) over.
    Q_SCRIPTABLE void Open(const QStringList &files, const QString &token);

Q_SIGNALS:
    void appearanceChanged();
    void openRequested(const QStringList &files);
    // A second launch with nothing to open: come to the front.
    void raiseRequested();

private:
    static App *s_instance;
    Options m_options;
    bool m_grabbed = false;
    bool m_choosing = false;
    mutable QStringList m_families;
};

// image://icon/NAME: an icon of the icon theme, for the document's icon in
// the title bar.
class Icons : public QQuickImageProvider
{
public:
    Icons();
    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requestedSize) override;
};
