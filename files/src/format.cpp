#include "format.h"

#include <QDateTime>
#include <QHash>
#include <QLocale>
#include <QMimeDatabase>
#include <QRegularExpression>

QString Format::size(qint64 bytes)
{
    if (bytes < 0)
        return QStringLiteral("--");
    if (bytes == 0)
        return QStringLiteral("Zero bytes");
    if (bytes == 1)
        return QStringLiteral("1 byte");
    if (bytes < 1000)
        return QStringLiteral("%1 bytes").arg(bytes);
    static const char *const units[] = {"KB", "MB", "GB", "TB", "PB"};
    double value = bytes / 1000.0;
    int unit = 0;
    while (value >= 999.5 && unit < 4) {
        value /= 1000.0;
        ++unit;
    }
    // Finder's precision: whole KB, one decimal for MB, two above.
    const int decimals = unit == 0 ? 0 : unit == 1 ? 1 : 2;
    const QLocale locale;
    QString text = locale.toString(value, 'f', decimals);
    if (decimals > 0) {
        while (text.endsWith(QLatin1Char('0')))
            text.chop(1);
        if (text.endsWith(locale.decimalPoint()))
            text.chop(locale.decimalPoint().size());
    }
    return text + QLatin1Char(' ') + QLatin1String(units[unit]);
}

QString Format::date(qint64 secs, int level)
{
    if (secs <= 0)
        return QStringLiteral("--");
    const QDateTime when = QDateTime::fromSecsSinceEpoch(secs);
    const QDate today = QDate::currentDate();
    const QLocale locale;
    const QString time = locale.toString(when.time(), QLocale::ShortFormat);
    const QString day = when.date() == today ? QStringLiteral("Today")
        : when.date() == today.addDays(-1)    ? QStringLiteral("Yesterday")
        : level == 0                          ? locale.toString(when.date(), QStringLiteral("MMM d, yyyy"))
                                              : locale.toString(when.date(), QStringLiteral("M/d/yy"));
    switch (level) {
    case 0:
        return QStringLiteral("%1 at %2").arg(day, time);
    case 1:
        return QStringLiteral("%1, %2").arg(day, time);
    default:
        return when.date() == today ? time : day;
    }
}

QString Format::longDate(qint64 secs)
{
    if (secs <= 0)
        return QStringLiteral("--");
    const QDateTime when = QDateTime::fromSecsSinceEpoch(secs);
    const QLocale locale;
    return QStringLiteral("%1 at %2").arg(locale.toString(when.date(), QStringLiteral("dddd, MMMM d, yyyy")),
                                          locale.toString(when.time(), QLocale::ShortFormat));
}

QString Format::secondsDate(qint64 secs)
{
    if (secs <= 0)
        return QStringLiteral("--");
    const QDateTime when = QDateTime::fromSecsSinceEpoch(secs);
    const QLocale locale;
    // The locale's long time without its time zone ("h:mm:ss AP t").
    static const QRegularExpression zone(QStringLiteral("\\s*t+\\s*"));
    QString time = locale.timeFormat(QLocale::LongFormat);
    time.replace(zone, QStringLiteral(" "));
    return QStringLiteral("%1 at %2").arg(locale.toString(when.date(), QStringLiteral("MMM d, yyyy")),
                                          locale.toString(when.time(), time.trimmed()));
}

QString Format::bytes(qint64 bytes)
{
    if (bytes < 0)
        return QStringLiteral("--");
    if (bytes == 0)
        return QStringLiteral("Zero bytes");
    if (bytes == 1)
        return QStringLiteral("1 byte");
    return QStringLiteral("%1 bytes").arg(QLocale().toString(bytes));
}

namespace {

// Finder's names for the kinds people meet most; others take
// shared-mime-info's description.
const QHash<QString, QString> &finderKinds()
{
    static const QHash<QString, QString> kinds = {
        {QStringLiteral("application/pdf"), QStringLiteral("PDF Document")},
        {QStringLiteral("text/plain"), QStringLiteral("Plain Text")},
        {QStringLiteral("text/markdown"), QStringLiteral("Markdown Document")},
        {QStringLiteral("text/html"), QStringLiteral("HTML text")},
        {QStringLiteral("text/csv"), QStringLiteral("comma-separated values")},
        {QStringLiteral("application/json"), QStringLiteral("JSON File")},
        {QStringLiteral("application/xml"), QStringLiteral("XML text")},
        {QStringLiteral("application/x-shellscript"), QStringLiteral("Shell Script")},
        {QStringLiteral("text/x-makefile"), QStringLiteral("Makefile")},
        {QStringLiteral("text/x-python3"), QStringLiteral("Python Script")},
        {QStringLiteral("text/x-python"), QStringLiteral("Python Script")},
        {QStringLiteral("text/x-c++src"), QStringLiteral("C++ Source")},
        {QStringLiteral("text/x-csrc"), QStringLiteral("C Source")},
        {QStringLiteral("text/x-chdr"), QStringLiteral("C Header Source")},
        {QStringLiteral("text/rust"), QStringLiteral("Rust Source")},
        {QStringLiteral("application/javascript"), QStringLiteral("JavaScript script")},
        {QStringLiteral("text/javascript"), QStringLiteral("JavaScript script")},
        {QStringLiteral("image/png"), QStringLiteral("PNG image")},
        {QStringLiteral("image/jpeg"), QStringLiteral("JPEG image")},
        {QStringLiteral("image/gif"), QStringLiteral("GIF image")},
        {QStringLiteral("image/heif"), QStringLiteral("HEIF image")},
        {QStringLiteral("image/heic"), QStringLiteral("HEIF image")},
        {QStringLiteral("image/webp"), QStringLiteral("WebP image")},
        {QStringLiteral("image/svg+xml"), QStringLiteral("SVG image")},
        {QStringLiteral("image/tiff"), QStringLiteral("TIFF image")},
        {QStringLiteral("application/zip"), QStringLiteral("ZIP archive")},
        {QStringLiteral("application/x-tar"), QStringLiteral("tar archive")},
        {QStringLiteral("application/gzip"), QStringLiteral("gzip compressed archive")},
        {QStringLiteral("application/x-compressed-tar"), QStringLiteral("gzip tar archive")},
        {QStringLiteral("application/x-7z-compressed"), QStringLiteral("7-Zip archive")},
        {QStringLiteral("application/x-iso9660-image"), QStringLiteral("Disk Image")},
        {QStringLiteral("audio/mpeg"), QStringLiteral("MP3 audio")},
        {QStringLiteral("audio/flac"), QStringLiteral("FLAC audio")},
        {QStringLiteral("audio/x-wav"), QStringLiteral("Waveform audio")},
        {QStringLiteral("audio/mp4"), QStringLiteral("MPEG-4 audio")},
        {QStringLiteral("video/mp4"), QStringLiteral("MPEG-4 movie")},
        {QStringLiteral("video/quicktime"), QStringLiteral("QuickTime movie")},
        {QStringLiteral("video/x-matroska"), QStringLiteral("Matroska video")},
        {QStringLiteral("video/webm"), QStringLiteral("WebM video")},
        {QStringLiteral("application/x-executable"), QStringLiteral("Unix executable")},
        {QStringLiteral("application/x-desktop"), QStringLiteral("Application")},
    };
    return kinds;
}

}

QString Format::kind(const QString &name, bool dir)
{
    if (dir)
        return QStringLiteral("Folder");
    static const QMimeDatabase mimes;
    const QMimeType mime = mimes.mimeTypeForFile(name, QMimeDatabase::MatchExtension);
    if (!mime.isValid() || mime.isDefault())
        return QStringLiteral("Document");
    const auto &kinds = finderKinds();
    if (auto it = kinds.find(mime.name()); it != kinds.end())
        return *it;
    for (const QString &alias : mime.aliases())
        if (auto it = kinds.find(alias); it != kinds.end())
            return *it;
    QString comment = mime.comment();
    if (!comment.isEmpty())
        comment[0] = comment[0].toUpper();
    return comment.isEmpty() ? QStringLiteral("Document") : comment;
}

QString Format::shortKind(const QString &kind)
{
    // "Plain Text" is "Text"; an acronym's document, archive, image, audio
    // or movie is the acronym ("PDF", "ZIP", "PNG"). "JSON File", "HTML
    // text" and "Markdown Document" have no shorter name.
    if (kind == QLatin1String("Plain Text"))
        return QStringLiteral("Text");
    static const QRegularExpression acronym(QStringLiteral("^([A-Z0-9][A-Z0-9-]*) (Document|archive|image|audio|movie)$"));
    const auto m = acronym.match(kind);
    return m.hasMatch() ? m.captured(1) : kind;
}

QString Format::icon(const QString &, bool dir)
{
    return dir ? QStringLiteral("folder") : QStringLiteral("document");
}

QString Format::badge(const QString &name, bool dir)
{
    if (dir)
        return {};
    const int dot = name.lastIndexOf(QLatin1Char('.'));
    if (dot <= 0 || name.size() - dot > 6)
        return {};
    return name.mid(dot + 1).toUpper();
}
