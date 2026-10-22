#pragma once

#include <QImage>
#include <QString>

class QFile;

// Thumbnails of the kinds Qt can't read as pictures, made the way Finder
// shows them, on the calling thread (one of the thumbnail pool's), each at
// most box pixels on its longer side. They read the file through the
// handle given, opened quietly, so making one doesn't mark the file opened.
namespace Previews {

// An early frame of a video: from a second in (Finder's isn't a dark first
// frame either), the most typical of the next 24, by ffmpeg reading the
// file on its standard input.
QImage video(QFile &file, int box);

// Finder's font tile: "Aa" set in the font, black on white, between two
// guide lines at its x-height and baseline.
QImage font(QFile &file, int box);

// An audio file's embedded cover (ID3, MP4, FLAC, Ogg, WAV), or none.
QImage audioCover(QFile &file, int box);

// An office document's first page or slide: the preview saved inside it,
// else, for Word, Excel and PowerPoint files, drawn from its XML (as Quick
// Look does; OpenDocument files without one stay icons, as in Finder).
// how says which: "saved", "word", "excel" or "slides".
QImage office(QFile &file, const QString &suffix, int box, QString *how = nullptr);

}
