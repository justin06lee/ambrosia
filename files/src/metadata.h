#pragma once

#include <QList>
#include <QSize>
#include <QString>

class QIODevice;

// What Finder's preview lists under Information beside an item's dates,
// read from the file's own header: a picture's Dimensions and Resolution,
// and behind Show More when it was taken, its color space and profile and
// the camera's make, model and settings; a PDF's version, pages, security
// and the software that wrote it. Rows come in Finder's order.
namespace Metadata {

struct Row {
    QString label, value;
    bool more = false; // shown only after Show More
};

// file is open for reading at any position; shown is a picture's size as
// it shows (turned as its camera says), invalid for anything else.
QList<Row> read(QIODevice &file, const QString &name, QSize shown);

}
