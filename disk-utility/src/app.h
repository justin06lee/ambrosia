#pragma once

#include <QColor>
#include <QObject>
#include <QQuickWindow>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// What the windows can't do from QML: the system's appearance, each
// window's shadow (KWin draws it), showing a folder in Files, the Open
// panel for a disk image, and a second launch handing over the image files
// it was asked to open.
class App : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_CLASSINFO("D-Bus Interface", "org.ambrosia.DiskUtility")
    Q_PROPERTY(bool dark READ dark NOTIFY appearanceChanged)
    Q_PROPERTY(QColor accent READ accent NOTIFY appearanceChanged)
    // Draw windows as the one in front (for grabs, where none is).
    Q_PROPERTY(bool active READ active CONSTANT)
    // Drawn with no screen (a grab on a machine without one): a mask draws
    // nothing there, so windows leave their corner masks off.
    Q_PROPERTY(bool offscreen READ offscreen CONSTANT)
    // The disk image files it was started with.
    Q_PROPERTY(QList<QUrl> files READ files CONSTANT)
    // For grabs: the device to choose by its short name (sda1), whether
    // every device is listed, and a sheet to show (erase, firstaid, info).
    Q_PROPERTY(QString show READ show CONSTANT)
    Q_PROPERTY(bool all READ all CONSTANT)
    Q_PROPERTY(QString sheet READ sheet CONSTANT)

public:
    struct Options {
        QString appearance; // "light" or "dark" forces it
        QString grab;       // save the window to this PNG once shown, then quit
        QString show;
        QString sheet;
        QList<QUrl> files;
        bool all = false;
        bool active = false;
    };

    explicit App(const Options &options);
    static App *create(QQmlEngine *, QJSEngine *);

    bool dark() const;
    QColor accent() const;
    bool active() const { return m_options.active; }
    bool offscreen() const;
    QList<QUrl> files() const { return m_options.files; }
    QString show() const { return m_options.show; }
    bool all() const { return m_options.all; }
    QString sheet() const { return m_options.sheet; }

    Q_INVOKABLE void decorate(QQuickWindow *window, int radius);
    // The main window is up: with --grab it is saved a little later and
    // the app leaves.
    Q_INVOKABLE void shown(QQuickWindow *window);
    Q_INVOKABLE void activate(QQuickWindow *window);
    // Open a folder (a volume's mount point) in Files.
    Q_INVOKABLE void reveal(const QString &path);
    // The Open panel, for a disk image: imageChosen with the one chosen.
    Q_INVOKABLE void chooseImage();
    // Where a new disk image may be saved without looking further: the
    // Desktop, Documents, Downloads and the home folder, [{ name, path }].
    Q_INVOKABLE QVariantList places() const;
    // The panel for any other folder, opened at `from`: folderChosen.
    Q_INVOKABLE void chooseFolder(const QString &from);
    // A folder's name as it is shown (the home folder by its owner's).
    Q_INVOKABLE QString folderName(const QString &path) const;
    Q_INVOKABLE bool exists(const QString &path) const;

public Q_SLOTS:
    // A second launch: open these disk images (none: bring the window
    // forward).
    Q_SCRIPTABLE void Open(const QStringList &files, const QString &token);

Q_SIGNALS:
    void appearanceChanged();
    void openRequested(const QList<QUrl> &files);
    void imageChosen(const QUrl &file);
    void folderChosen(const QString &path);

private:
    static App *s_instance;
    Options m_options;
    bool m_grabbed = false;
    bool m_choosing = false;
};
