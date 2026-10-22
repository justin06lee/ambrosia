#include "metadata.h"
#include "format.h"

#include <QDateTime>
#include <QFileInfo>
#include <QIODevice>
#include <QLocale>
#include <QMap>
#include <QRegularExpression>

#include <algorithm>
#include <cctype>
#include <cmath>
#include <cstring>

namespace {

using Metadata::Row;

quint32 be32(const uchar *p)
{
    return quint32(p[0]) << 24 | quint32(p[1]) << 16 | quint32(p[2]) << 8 | p[3];
}

// "5.0938", "5.8", "4": at most the decimals given, without trailing zeros.
QString number(double value, int decimals)
{
    QString text = QLocale(QLocale::English).toString(value, 'f', decimals);
    if (text.contains(QLatin1Char('.'))) {
        while (text.endsWith(QLatin1Char('0')))
            text.chop(1);
        if (text.endsWith(QLatin1Char('.')))
            text.chop(1);
    }
    return text;
}

QString utf16be(const uchar *p, qsizetype bytes)
{
    QString text;
    text.reserve(bytes / 2);
    for (qsizetype i = 0; i + 1 < bytes; i += 2)
        text.append(QChar(char16_t(p[i] << 8 | p[i + 1])));
    return text;
}

// What a picture's header says, as read.
struct Picture {
    double dpiX = 0, dpiY = 0; // JFIF's or PNG's density, in dots an inch
    double exifX = 0, exifY = 0;
    int exifUnit = 2; // EXIF's ResolutionUnit: 2 inches, 3 centimetres
    QString space; // "RGB", "Gray", "CMYK"
    QString profile; // the ICC profile's description
    QString make, model, taken; // taken as EXIF writes it: "2012:01:26 19:07:41"
    double exposure = 0, aperture = -1, focal = 0;
    int exifSpace = 0; // EXIF's ColorSpace: 1 sRGB
};

// An EXIF block (a TIFF header and its IFDs): the camera, its settings,
// when it was taken and the resolution it gives.
struct Tiff {
    const uchar *p;
    qsizetype n;
    bool le;
    quint16 u16(qsizetype at) const
    {
        if (at < 0 || at + 2 > n)
            return 0;
        return le ? quint16(p[at] | p[at + 1] << 8) : quint16(p[at] << 8 | p[at + 1]);
    }
    quint32 u32(qsizetype at) const
    {
        if (at < 0 || at + 4 > n)
            return 0;
        return le ? quint32(p[at]) | quint32(p[at + 1]) << 8 | quint32(p[at + 2]) << 16 | quint32(p[at + 3]) << 24 : be32(p + at);
    }
    // Where an entry's value is: in the entry when it takes 4 bytes or fewer.
    qsizetype valueAt(qsizetype entry, quint16 type, quint32 count) const
    {
        static const int sizes[] = {0, 1, 1, 2, 4, 8, 1, 1, 2, 4, 8, 4, 8};
        const qint64 bytes = type < 13 ? qint64(sizes[type]) * count : 0;
        return bytes <= 4 ? entry + 8 : qsizetype(u32(entry + 8));
    }
    QString ascii(qsizetype at, quint32 count) const
    {
        if (at < 0 || at + qsizetype(count) > n)
            return {};
        QByteArray text(reinterpret_cast<const char *>(p + at), count);
        if (const qsizetype end = text.indexOf('\0'); end >= 0)
            text.truncate(end);
        return QString::fromLatin1(text).trimmed();
    }
    double rational(qsizetype at, bool sign) const
    {
        const quint32 num = u32(at), den = u32(at + 4);
        if (den == 0)
            return 0;
        return sign ? double(qint32(num)) / qint32(den) : double(num) / den;
    }
    template<typename Each>
    void ifd(qsizetype at, Each each) const
    {
        if (at <= 0 || at + 2 > n)
            return;
        const int entries = u16(at);
        for (int i = 0; i < entries; ++i) {
            const qsizetype entry = at + 2 + 12 * i;
            if (entry + 12 > n)
                return;
            const quint16 type = u16(entry + 2);
            const quint32 count = u32(entry + 4);
            each(u16(entry), type, count, valueAt(entry, type, count));
        }
    }
};

void readTiff(const uchar *p, qsizetype n, Picture &pic)
{
    if (n < 8 || !((p[0] == 'I' && p[1] == 'I') || (p[0] == 'M' && p[1] == 'M')))
        return;
    const Tiff tiff{p, n, p[0] == 'I'};
    qsizetype exif = 0;
    tiff.ifd(tiff.u32(4), [&](quint16 tag, quint16, quint32 count, qsizetype value) {
        switch (tag) {
        case 0x010F: pic.make = tiff.ascii(value, count); break;
        case 0x0110: pic.model = tiff.ascii(value, count); break;
        case 0x011A: pic.exifX = tiff.rational(value, false); break;
        case 0x011B: pic.exifY = tiff.rational(value, false); break;
        case 0x0128: pic.exifUnit = tiff.u16(value); break;
        case 0x8769: exif = tiff.u32(value); break;
        }
    });
    tiff.ifd(exif, [&](quint16 tag, quint16, quint32 count, qsizetype value) {
        switch (tag) {
        case 0x9003: pic.taken = tiff.ascii(value, count); break;
        case 0x829A: pic.exposure = tiff.rational(value, false); break;
        case 0x9202: pic.aperture = tiff.rational(value, false); break;
        case 0x920A: pic.focal = tiff.rational(value, false); break;
        case 0xA001: pic.exifSpace = tiff.u16(value); break;
        }
    });
}

// An ICC profile's description ('desc', in v2's form or v4's 'mluc').
QString iccName(const QByteArray &icc)
{
    const auto *p = reinterpret_cast<const uchar *>(icc.constData());
    const qsizetype n = icc.size();
    if (n < 132)
        return {};
    const quint32 count = be32(p + 128);
    for (quint32 i = 0; i < count && 132 + 12 * qsizetype(i + 1) <= n; ++i) {
        const uchar *entry = p + 132 + 12 * i;
        if (std::memcmp(entry, "desc", 4) != 0)
            continue;
        const quint32 at = be32(entry + 4), size = be32(entry + 8);
        if (size < 16 || qint64(at) + size > n)
            return {};
        const uchar *tag = p + at;
        if (std::memcmp(tag, "desc", 4) == 0) {
            const quint32 length = be32(tag + 8);
            if (12 + qint64(length) > size)
                return {};
            QByteArray text(reinterpret_cast<const char *>(tag + 12), length);
            if (const qsizetype end = text.indexOf('\0'); end >= 0)
                text.truncate(end);
            return QString::fromLatin1(text).trimmed();
        }
        if (std::memcmp(tag, "mluc", 4) == 0 && be32(tag + 8) > 0) {
            const uchar *record = tag + 16; // the first language's
            const quint32 length = be32(record + 4), from = be32(record + 8);
            if (qint64(from) + length > size)
                return {};
            return utf16be(tag + from, length).trimmed();
        }
        return {};
    }
    return {};
}

void readJpeg(QIODevice &file, Picture &pic)
{
    file.seek(0);
    const QByteArray head = file.read(256 * 1024);
    const auto *p = reinterpret_cast<const uchar *>(head.constData());
    const qsizetype n = head.size();
    QMap<int, QByteArray> icc; // its pieces by number, from 1
    qsizetype at = 2;
    while (at + 4 <= n && p[at] == 0xFF) {
        const uchar marker = p[at + 1];
        if (marker == 0xFF) { // fill
            ++at;
            continue;
        }
        if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
            at += 2;
            continue;
        }
        if (marker == 0xDA || marker == 0xD9) // the picture itself
            break;
        const qsizetype segment = at + 4, end = std::min(n, at + 2 + (p[at + 2] << 8 | p[at + 3]));
        if (marker == 0xE0 && segment + 12 <= end && std::memcmp(p + segment, "JFIF\0", 5) == 0) {
            const int units = p[segment + 7];
            const double x = p[segment + 8] << 8 | p[segment + 9], y = p[segment + 10] << 8 | p[segment + 11];
            if (units == 1 || units == 2) {
                pic.dpiX = units == 1 ? x : x * 2.54;
                pic.dpiY = units == 1 ? y : y * 2.54;
            }
        } else if (marker == 0xE1 && segment + 6 <= end && std::memcmp(p + segment, "Exif\0\0", 6) == 0) {
            readTiff(p + segment + 6, end - segment - 6, pic);
        } else if (marker == 0xE2 && segment + 14 <= end && std::memcmp(p + segment, "ICC_PROFILE\0", 12) == 0) {
            icc.insert(p[segment + 12], QByteArray(reinterpret_cast<const char *>(p + segment + 14), end - segment - 14));
        } else if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC && segment + 6 <= end) {
            const int components = p[segment + 5];
            pic.space = components == 1 ? QStringLiteral("Gray") : components == 4 ? QStringLiteral("CMYK") : QStringLiteral("RGB");
        }
        at = end;
    }
    QByteArray profile;
    for (const QByteArray &piece : std::as_const(icc))
        profile += piece;
    pic.profile = iccName(profile);
}

void readPng(QIODevice &file, Picture &pic)
{
    file.seek(8);
    for (int chunks = 0; chunks < 64; ++chunks) {
        const QByteArray header = file.read(8);
        if (header.size() < 8)
            return;
        const quint32 length = be32(reinterpret_cast<const uchar *>(header.constData()));
        const QByteArray type = header.mid(4, 4);
        if (type == "IDAT" || type == "IEND" || length > 4 * 1024 * 1024)
            return;
        const bool wanted = type == "IHDR" || type == "pHYs" || type == "iCCP" || type == "sRGB" || type == "eXIf";
        if (!wanted) {
            file.seek(file.pos() + length + 4);
            continue;
        }
        const QByteArray data = file.read(length);
        file.read(4); // its CRC
        const auto *d = reinterpret_cast<const uchar *>(data.constData());
        if (type == "IHDR" && data.size() >= 13) {
            pic.space = d[9] == 0 || d[9] == 4 ? QStringLiteral("Gray") : QStringLiteral("RGB");
        } else if (type == "pHYs" && data.size() >= 9 && d[8] == 1) { // dots a metre
            pic.dpiX = be32(d) * 0.0254;
            pic.dpiY = be32(d + 4) * 0.0254;
        } else if (type == "iCCP") {
            const qsizetype end = data.indexOf('\0');
            if (end > 0 && end + 2 < data.size()) {
                // qUncompress wants the size first; it grows past a guess.
                const QByteArray zipped = data.mid(end + 2);
                const quint32 guess = quint32(zipped.size()) * 4;
                const char size[4] = {char(guess >> 24), char(guess >> 16), char(guess >> 8), char(guess)};
                pic.profile = iccName(qUncompress(QByteArray(size, 4) + zipped));
            }
        } else if (type == "sRGB" && pic.profile.isEmpty()) {
            pic.profile = QStringLiteral("sRGB IEC61966-2.1");
        } else if (type == "eXIf") {
            readTiff(d, data.size(), pic);
        }
    }
}

// A PDF string after a key: a literal's escapes undone, a hex string read;
// UTF-16 when it starts with its byte-order mark, PDFDocEncoding (about
// Latin-1) otherwise.
QString pdfString(const QByteArray &data, qsizetype at)
{
    while (at < data.size() && std::isspace(uchar(data[at])))
        ++at;
    QByteArray bytes;
    if (at < data.size() && data[at] == '(') {
        int depth = 1;
        for (++at; at < data.size() && depth > 0; ++at) {
            const char c = data[at];
            if (c == '\\' && at + 1 < data.size()) {
                const char e = data[++at];
                if (e >= '0' && e <= '7') {
                    int value = 0;
                    for (int digits = 0; digits < 3 && at < data.size() && data[at] >= '0' && data[at] <= '7'; ++digits, ++at)
                        value = value * 8 + (data[at] - '0');
                    --at;
                    bytes += char(value);
                } else {
                    const char *from = "nrtbf", *to = "\n\r\t\b\f";
                    const char *hit = std::strchr(from, e);
                    if (hit && e != '\0')
                        bytes += to[hit - from];
                    else if (e != '\n' && e != '\r')
                        bytes += e;
                }
            } else if (c == '(') {
                ++depth;
                bytes += c;
            } else if (c == ')') {
                if (--depth > 0)
                    bytes += c;
            } else {
                bytes += c;
            }
        }
    } else if (at < data.size() && data[at] == '<') {
        const qsizetype end = data.indexOf('>', at);
        if (end < 0)
            return {};
        QByteArray hex = data.mid(at + 1, end - at - 1);
        hex.replace(' ', "").replace('\n', "").replace('\r', "");
        bytes = QByteArray::fromHex(hex);
    } else {
        return {};
    }
    if (bytes.startsWith("\xFE\xFF"))
        return utf16be(reinterpret_cast<const uchar *>(bytes.constData()) + 2, bytes.size() - 2).trimmed();
    return QString::fromLatin1(bytes).trimmed();
}

QList<Row> readPdf(QIODevice &file)
{
    file.seek(0);
    const QByteArray head = file.read(64 * 1024);
    if (!head.startsWith("%PDF-"))
        return {};
    QByteArray all = head;
    if (const qint64 size = file.size(); size > head.size()) {
        file.seek(std::max<qint64>(head.size(), size - 64 * 1024));
        all += file.read(64 * 1024);
    }
    QList<Row> rows;
    static const QRegularExpression version(QStringLiteral("^%PDF-(\\d\\.\\d)"));
    if (const auto m = version.match(QString::fromLatin1(head.left(16))); m.hasMatch())
        rows.append({QStringLiteral("Version"), m.captured(1), true});
    // Its pages: the linearization dictionary's count, else the page tree's.
    const QString text = QString::fromLatin1(all);
    static const QRegularExpression linearized(QStringLiteral("/Linearized\\b[^>]*?/N\\s+(\\d+)"));
    static const QRegularExpression tree(QStringLiteral("<<((?:(?!>>|<<).)*?/Type\\s*/Pages\\b(?:(?!>>|<<).)*)>>"),
                                         QRegularExpression::DotMatchesEverythingOption);
    static const QRegularExpression countKey(QStringLiteral("/Count\\s+(\\d+)"));
    int pages = 0;
    if (const auto m = linearized.match(text); m.hasMatch()) {
        pages = m.captured(1).toInt();
    } else {
        for (auto it = tree.globalMatch(text); it.hasNext();)
            if (const auto count = countKey.match(it.next().captured(1)); count.hasMatch())
                pages = std::max(pages, count.captured(1).toInt());
    }
    if (pages > 0)
        rows.append({QStringLiteral("Pages"), QLocale(QLocale::English).toString(pages), true});
    rows.append({QStringLiteral("Security"), all.contains("/Encrypt") ? QStringLiteral("Encrypted") : QStringLiteral("None"), true});
    QString producer;
    if (const qsizetype at = all.lastIndexOf("/Producer"); at >= 0)
        producer = pdfString(all, at + 9);
    static const QRegularExpression xmp(QStringLiteral("<pdf:Producer>([^<]*)</pdf:Producer>"));
    if (producer.isEmpty())
        if (const auto m = xmp.match(text); m.hasMatch())
            producer = m.captured(1).trimmed();
    if (!producer.isEmpty())
        rows.append({QStringLiteral("Encoding software"), producer, true});
    return rows;
}

} // namespace

namespace Metadata {

QList<Row> read(QIODevice &file, const QString &name, QSize shown)
{
    const QString ext = QFileInfo(name).suffix().toLower();
    if (ext == u"pdf")
        return readPdf(file);
    if (!shown.isValid() || ext == u"svg" || ext == u"svgz")
        return shown.isValid() ? QList<Row>{{QStringLiteral("Dimensions"), QStringLiteral("%1×%2").arg(shown.width()).arg(shown.height())}} : QList<Row>{};

    Picture pic;
    if (ext == u"jpg" || ext == u"jpeg" || ext == u"jpe" || ext == u"jfif")
        readJpeg(file, pic);
    else if (ext == u"png")
        readPng(file, pic);
    QList<Row> rows;
    if (!pic.taken.isEmpty()) {
        const QDateTime taken = QDateTime::fromString(pic.taken, QStringLiteral("yyyy:MM:dd HH:mm:ss"));
        if (taken.isValid())
            rows.append({QStringLiteral("Content created"), Format::date(taken.toSecsSinceEpoch(), 1), true});
    }
    rows.append({QStringLiteral("Dimensions"), QStringLiteral("%1×%2").arg(shown.width()).arg(shown.height())});
    // Its resolution: EXIF's, else JFIF's or PNG's, else the 72 dpi
    // Finder takes for a picture that gives none.
    double x = 72, y = 72;
    if (pic.exifX > 0 && pic.exifY > 0) {
        const double scale = pic.exifUnit == 3 ? 2.54 : 1;
        x = pic.exifX * scale;
        y = pic.exifY * scale;
    } else if (pic.dpiX > 0 && pic.dpiY > 0) {
        x = pic.dpiX;
        y = pic.dpiY;
    }
    rows.append({QStringLiteral("Resolution"), QStringLiteral("%1×%2").arg(qRound(x)).arg(qRound(y))});
    if (!pic.space.isEmpty())
        rows.append({QStringLiteral("Color space"), pic.space, true});
    // A camera's picture without a profile of its own is sRGB when its EXIF
    // says so, as ImageIO takes it.
    if (pic.profile.isEmpty() && pic.exifSpace == 1)
        pic.profile = QStringLiteral("sRGB IEC61966-2.1");
    if (!pic.profile.isEmpty())
        rows.append({QStringLiteral("Color profile"), pic.profile, true});
    if (!pic.make.isEmpty())
        rows.append({QStringLiteral("Device make"), pic.make, true});
    if (!pic.model.isEmpty())
        rows.append({QStringLiteral("Device model"), pic.model, true});
    if (pic.aperture >= 0)
        rows.append({QStringLiteral("Aperture value"), number(pic.aperture, 4), true});
    if (pic.exposure > 0)
        rows.append({QStringLiteral("Exposure time"),
                     pic.exposure < 1 ? QStringLiteral("1/") + QLocale(QLocale::English).toString(qRound(1 / pic.exposure)) : number(pic.exposure, 1), true});
    if (pic.focal > 0)
        rows.append({QStringLiteral("Focal length"), number(pic.focal, 2) + QStringLiteral(" mm"), true});
    return rows;
}

}
