#pragma once

#include <QQuickImageProvider>

#include <memory>

class QPdfDocument;

// image://page/DOCUMENT/PAGE: a PDF's page drawn at the size asked for, on
// white, off the main thread. Documents say they are open (and closed) by
// their id; a page being drawn keeps its document until it is done.
class Pages : public QQuickImageProvider
{
public:
    Pages();
    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override;

    static void add(const QString &id, const std::shared_ptr<QPdfDocument> &document);
    static void remove(const QString &id);
    // The most pixels a page is drawn along its longer side: past it the
    // picture is stretched (a whole page at eight times would be gigabytes).
    static constexpr int longest = 5200;
};
