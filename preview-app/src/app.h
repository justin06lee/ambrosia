#pragma once

#include <QColor>
#include <QObject>
#include <QQuickWindow>
#include <QSize>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// What the windows can't do from QML: the system's appearance, each
// window's shadow (KWin draws it), the clipboard, what kind of file a path
// holds, the Open panel, and files handed over by a second launch.
class App : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.ambrosia.Preview")
    Q_PROPERTY(bool dark READ dark NOTIFY appearanceChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY appearanceChanged)
    // Draw windows as the one in front (for grabs, where none is).
    Q_PROPERTY(bool active READ active CONSTANT)
    // The files asked for on the command line, as URLs.
    Q_PROPERTY(QStringList files READ files CONSTANT)
    // For grabs: what to search a PDF for, the zoom, and the sidebar
    // ("none", "thumbnails", "outline") as it opens; 0 and "" leave them be.
    Q_PROPERTY(QString find READ find CONSTANT)
    Q_PROPERTY(qreal zoom READ zoom CONSTANT)
    Q_PROPERTY(QString sidebar READ sidebar CONSTANT)

public:
    struct Options {
        QStringList files;
        QString appearance; // "light" or "dark" forces it
        QString grab;       // save the first window to this PNG once shown, then quit
        QString find;
        QString sidebar;
        qreal zoom = 0;
        bool active = false;
    };

    explicit App(const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);

    bool dark() const;
    QColor accent() const;
    bool active() const { return m_options.active; }
    QStringList files() const { return m_options.files; }
    QString find() const { return m_options.find; }
    QString sidebar() const { return m_options.sidebar; }
    qreal zoom() const { return m_options.zoom; }

    Q_INVOKABLE void decorate(QQuickWindow *window, int radius);
    Q_INVOKABLE void shown(QQuickWindow *window);
    Q_INVOKABLE void activate(QQuickWindow *window);
    Q_INVOKABLE void copy(const QString &text);
    // A picture to the clipboard, turned as it shows.
    Q_INVOKABLE void copyPicture(const QUrl &file, int quarterTurns);
    // Whether the file is a PDF (by what it holds, not its name).
    Q_INVOKABLE bool isPdf(const QUrl &file) const;
    // Pictures as a PDF to print, a page each, as large as the paper
    // (its size in points) takes whole, a quarter inch in from its edges.
    Q_INVOKABLE bool picturesPdf(const QVariantList &files, const QUrl &target, const QSizeF &paper) const;
    // A picture's size as it shows (turned as its camera says); empty when
    // the file isn't a picture that can be read.
    Q_INVOKABLE QSize imageSize(const QUrl &file) const;
    // The name a window shows for the file.
    Q_INVOKABLE QString name(const QUrl &file) const;
    // The Open panel (the desktop's, through the portal): openRequested with
    // what was chosen, or chooseCancelled.
    Q_INVOKABLE void chooseFiles();

    // A URL for each argument: a path (taken from the folder the app was
    // started in) or a URL already.
    static QStringList urls(const QStringList &arguments);

public Q_SLOTS:
    // A second launch hands its files (and its activation token) over.
    Q_SCRIPTABLE void Open(const QStringList &files, const QString &token);

Q_SIGNALS:
    void appearanceChanged();
    void openRequested(const QStringList &files);
    void chooseCancelled();

private:
    static App *s_instance;
    Options m_options;
    bool m_grabbed = false;
    bool m_choosing = false;
};
