#pragma once

#include <QObject>
#include <QtQml/qqmlregistration.h>

// Accessibility: what KWin and KDE's own settings can do of the Mac's pane.
// Zoom and the lens, color filters and shaking the pointer to find it are
// KWin's effects (kwinrc [Plugins], loaded or unloaded at once); Sticky,
// Slow and Mouse Keys and the screen's flash for an alert are kaccessrc,
// which KWin watches; the pointer's size is kcminputrc; reduce motion and a
// cursor that doesn't blink are kdeglobals, which apps read.
class Access : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool zoom READ zoom WRITE setZoom NOTIFY changed)
    // "full" (the whole screen zooms) or "lens" (a magnifier at the pointer).
    Q_PROPERTY(QString zoomStyle READ zoomStyle WRITE setZoomStyle NOTIFY changed)
    // KWin's keys for it, as glyphs ("⌘=" …), "" where none is set.
    Q_PROPERTY(QString zoomInKeys READ zoomInKeys NOTIFY changed)
    Q_PROPERTY(QString zoomOutKeys READ zoomOutKeys NOTIFY changed)
    Q_PROPERTY(QString scrollZoomKeys READ scrollZoomKeys NOTIFY changed)
    Q_PROPERTY(bool colorFilters READ colorFilters WRITE setColorFilters NOTIFY changed)
    // 0 red/green (protanopia), 1 green/red (deuteranopia), 2 blue/yellow (tritanopia).
    Q_PROPERTY(int colorFilter READ colorFilter WRITE setColorFilter NOTIFY changed)
    // 0 (normal, 24) .. 1 (large, 72).
    Q_PROPERTY(qreal pointerSize READ pointerSize WRITE setPointerSize NOTIFY changed)
    Q_PROPERTY(bool shakeToLocate READ shakeToLocate WRITE setShakeToLocate NOTIFY changed)
    Q_PROPERTY(bool reduceMotion READ reduceMotion WRITE setReduceMotion NOTIFY changed)
    Q_PROPERTY(bool steadyCursor READ steadyCursor WRITE setSteadyCursor NOTIFY changed)
    Q_PROPERTY(bool flashScreen READ flashScreen WRITE setFlashScreen NOTIFY changed)
    Q_PROPERTY(bool stickyKeys READ stickyKeys WRITE setStickyKeys NOTIFY changed)
    Q_PROPERTY(bool slowKeys READ slowKeys WRITE setSlowKeys NOTIFY changed)
    Q_PROPERTY(bool mouseKeys READ mouseKeys WRITE setMouseKeys NOTIFY changed)

public:
    explicit Access(QObject *parent = nullptr);

    bool zoom() const;
    void setZoom(bool on);
    QString zoomStyle() const;
    void setZoomStyle(const QString &style);
    QString zoomInKeys() const;
    QString zoomOutKeys() const;
    QString scrollZoomKeys() const;
    bool colorFilters() const;
    void setColorFilters(bool on);
    int colorFilter() const;
    void setColorFilter(int mode);
    qreal pointerSize() const;
    void setPointerSize(qreal value);
    bool shakeToLocate() const;
    void setShakeToLocate(bool on);
    bool reduceMotion() const;
    void setReduceMotion(bool on);
    bool steadyCursor() const;
    void setSteadyCursor(bool on);
    bool flashScreen() const;
    void setFlashScreen(bool on);
    bool stickyKeys() const;
    void setStickyKeys(bool on);
    bool slowKeys() const;
    void setSlowKeys(bool on);
    bool mouseKeys() const;
    void setMouseKeys(bool on);

public Q_SLOTS:
    // Reads the files again (another program may have changed them).
    void read();

Q_SIGNALS:
    void changed();

private:
    bool plugin(const char *key, bool byDefault) const;
    void setPlugin(const char *key, const char *effect, bool on);
    bool access(const char *group, const char *key) const;
    void setAccess(const char *group, const char *key, bool on);
};
