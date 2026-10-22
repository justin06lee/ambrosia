#pragma once

#include <QImage>
#include <QQuickAsyncImageProvider>
#include <QString>
#include <QUrl>

// Thumbnails for QML, as image://thumb/MTIME/PATH (the path percent-encoded;
// the time makes a changed file ask again), with /tile after it for one
// framed as Finder frames its icons' thumbnails. They come from the freedesktop
// cache that Dolphin and GTK apps share (~/.cache/thumbnails), or are made
// on two background threads (nice 10, idle I/O): the newest view's first,
// dropped once its item scrolls away, and paused while the disk is under
// pressure (/proc/pressure/io).
class Thumbnailer : public QQuickAsyncImageProvider
{
public:
    ~Thumbnailer() override;
    QQuickImageResponse *requestImageResponse(const QString &id, const QSize &requestedSize) override;

    // The source QML shows for an item, or "" when it has none: decided by
    // its name alone, so it costs no I/O. mtime in seconds.
    static QString source(const QUrl &url, const QString &name, bool isDir, qint64 mtime);

    // One thumbnail made on the calling thread, at most box pixels on its
    // longer side, without the cache (for the benchmark); how says which
    // way it was made.
    static QImage make(const QString &path, int box, QString *how = nullptr);
    // Finder's frame for a thumbnail shown as an icon (an image://thumb/…/tile
    // source), on a box-pixel square.
    static QImage frame(const QImage &image, int box);
};
