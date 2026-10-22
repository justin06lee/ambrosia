#include "previews.h"

#include <KArchiveDirectory>
#include <KArchiveFile>
#include <KZip>

#include <QBuffer>
#include <QDir>
#include <QFile>
#include <QFontDatabase>
#include <QHash>
#include <QImageReader>
#include <QLinearGradient>
#include <QPainter>
#include <QPainterPath>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextLayout>
#include <QXmlStreamReader>
#include <QtMath>

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_MULTIPLE_MASTERS_H
#include FT_OUTLINE_H

#include <taglib/fileref.h>
#include <taglib/tfilestream.h>
#include <taglib/tvariant.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <memory>
#include <type_traits>
#include <vector>

#include <cerrno>
#include <csignal>
#include <fcntl.h>
#include <poll.h>
#include <spawn.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

namespace {

QImage fit(const QImage &image, int box)
{
    if (image.isNull() || (image.width() <= box && image.height() <= box))
        return image;
    return image.scaled(box, box, Qt::KeepAspectRatio, Qt::SmoothTransformation);
}

// A picture from bytes, decoded at the size wanted (JPEG covers decode an
// eighth of the work that way).
QImage decode(const QByteArray &bytes, int box)
{
    QBuffer buffer;
    buffer.setData(bytes);
    buffer.open(QIODevice::ReadOnly);
    QImageReader reader(&buffer);
    reader.setAutoTransform(true);
    const QSize size = reader.size();
    if (size.isValid() && (size.width() > box || size.height() > box))
        reader.setScaledSize(size.scaled(box, box, Qt::KeepAspectRatio));
    return fit(reader.read(), box);
}

// ---- Video ----------------------------------------------------------------

// Runs a program with the file on its standard input and returns what it
// wrote, or nothing if it failed or ran past the time given. It is spawned
// from the calling thread, so it shares its nice value and idle I/O class.
QByteArray run(const QByteArray &program, const QList<QByteArray> &args, int input, std::chrono::milliseconds limit)
{
    int out[2];
    if (::pipe2(out, O_CLOEXEC) != 0)
        return {};
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, input, STDIN_FILENO);
    posix_spawn_file_actions_adddup2(&actions, out[1], STDOUT_FILENO);
    posix_spawn_file_actions_addopen(&actions, STDERR_FILENO, "/dev/null", O_WRONLY, 0);
    std::vector<char *> argv;
    argv.push_back(const_cast<char *>(program.constData()));
    for (const QByteArray &arg : args)
        argv.push_back(const_cast<char *>(arg.constData()));
    argv.push_back(nullptr);
    pid_t pid = 0;
    const int spawned = posix_spawn(&pid, program.constData(), &actions, nullptr, argv.data(), environ);
    posix_spawn_file_actions_destroy(&actions);
    ::close(out[1]);
    if (spawned != 0) {
        ::close(out[0]);
        return {};
    }
    QByteArray data;
    bool killed = false;
    const auto deadline = std::chrono::steady_clock::now() + limit;
    for (;;) {
        const auto left = std::chrono::duration_cast<std::chrono::milliseconds>(deadline - std::chrono::steady_clock::now()).count();
        pollfd p{out[0], POLLIN, 0};
        const int ready = left > 0 ? ::poll(&p, 1, int(left)) : 0;
        if (ready < 0 && errno == EINTR)
            continue;
        if (ready <= 0 || data.size() > (32 << 20)) {
            ::kill(pid, SIGKILL);
            killed = true;
            break;
        }
        char buffer[64 << 10];
        const ssize_t n = ::read(out[0], buffer, sizeof buffer);
        if (n > 0)
            data.append(buffer, n);
        else if (n == 0 || (errno != EINTR && errno != EAGAIN))
            break;
    }
    ::close(out[0]);
    int status = 0;
    while (::waitpid(pid, &status, 0) < 0 && errno == EINTR) {
    }
    return !killed && WIFEXITED(status) && WEXITSTATUS(status) == 0 ? data : QByteArray();
}

const QByteArray &ffmpeg()
{
    static const QByteArray path = QFile::encodeName(QStandardPaths::findExecutable(QStringLiteral("ffmpeg")));
    return path;
}

// ---- Office ---------------------------------------------------------------

QByteArray entry(const KArchiveDirectory *root, const QString &path)
{
    const KArchiveEntry *e = root->entry(path);
    if (!e || !e->isFile())
        return {};
    const auto *file = static_cast<const KArchiveFile *>(e);
    return file->size() > (48 << 20) ? QByteArray() : file->data();
}

QString attr(const QXmlStreamReader &xml, QStringView name)
{
    for (const QXmlStreamAttribute &a : xml.attributes())
        if (a.name() == name)
            return a.value().toString();
    return {};
}

// An attribute in a namespace (r:id, r:embed beside a plain id).
QString nsAttr(const QXmlStreamReader &xml, QStringView name)
{
    for (const QXmlStreamAttribute &a : xml.attributes())
        if (a.name() == name && !a.namespaceUri().isEmpty())
            return a.value().toString();
    return {};
}

double number(const QString &text, double fallback = 0)
{
    bool ok = false;
    const double value = text.toDouble(&ok);
    return ok ? value : fallback;
}

// Calls at() at each element under the current one; at() returns true when
// it read the element through its end.
template<typename F>
void within(QXmlStreamReader &xml, F at)
{
    for (int depth = 1; depth > 0 && !xml.atEnd() && !xml.hasError();) {
        const auto token = xml.readNext();
        if (token == QXmlStreamReader::StartElement) {
            if (!at())
                ++depth;
        } else if (token == QXmlStreamReader::EndElement) {
            --depth;
        }
    }
}

// A part's relationships, by id and by type ("thumbnail", "slide"…), with
// their targets made paths in the package.
struct Rels {
    QHash<QString, QString> byId;
    QHash<QString, QString> byType;
};

Rels relsOf(const KArchiveDirectory *root, const QString &part)
{
    const qsizetype slash = part.lastIndexOf(QLatin1Char('/'));
    const QString base = part.left(slash + 1);
    Rels rels;
    QXmlStreamReader xml(entry(root, base + QStringLiteral("_rels/") + part.mid(slash + 1) + QStringLiteral(".rels")));
    while (!xml.atEnd() && !xml.hasError()) {
        if (xml.readNext() != QXmlStreamReader::StartElement || xml.name() != u"Relationship" || attr(xml, u"TargetMode") == u"External")
            continue;
        const QString target = attr(xml, u"Target");
        const QString path = target.startsWith(QLatin1Char('/')) ? target.mid(1) : QDir::cleanPath(base + target);
        const QString type = attr(xml, u"Type").section(QLatin1Char('/'), -1);
        rels.byId.insert(attr(xml, u"Id"), path);
        if (!rels.byType.contains(type))
            rels.byType.insert(type, path);
    }
    return rels;
}

QColor hex(const QString &value)
{
    // Excel's are ARGB (FF2A6DF4), the others RGB.
    const QString rgb = value.size() == 8 ? value.mid(2) : value;
    return rgb.size() == 6 ? QColor::fromString(QString(QLatin1Char('#') + rgb)) : QColor();
}

QFont sans(qreal px, bool bold)
{
    QFont font = QFontDatabase::systemFont(QFontDatabase::GeneralFont);
    font.setPixelSize(std::max(1, qRound(px)));
    font.setBold(bold);
    return font;
}

struct Run {
    QString text;
    qreal pt = -1;  // unset
    int bold = -1;  // unset, 0 or 1
    QColor color;   // invalid: unset
};

struct Para {
    QList<Run> runs;
    int align = -1; // unset, else Qt::Alignment
    qreal before = -1, after = -1; // twips (Word)
    qreal endPt = -1;
    QString style;
};

// Lays out a paragraph's runs in width px from y, wrapped; draws it if a
// painter is given. Returns its height. pxPerPt turns a run's points into
// pixels; leading scales the lines (Word's 1.08).
qreal layOut(QPainter *painter, const Para &para, qreal x, qreal y, qreal width, qreal pxPerPt, const Run &base, qreal leading, bool wrap = true)
{
    QString text;
    QList<QTextLayout::FormatRange> ranges;
    qreal biggest = 0;
    for (const Run &run : para.runs) {
        const qreal pt = run.pt > 0 ? run.pt : base.pt;
        biggest = std::max(biggest, pt);
        QTextLayout::FormatRange range;
        range.start = int(text.size());
        range.length = int(run.text.size());
        range.format.setFont(sans(pt * pxPerPt, run.bold >= 0 ? run.bold == 1 : base.bold == 1));
        range.format.setForeground(run.color.isValid() ? run.color : base.color.isValid() ? base.color : QColor(Qt::black));
        ranges.append(range);
        text += run.text;
    }
    const qreal emptyPt = para.endPt > 0 ? para.endPt : base.pt;
    if (text.isEmpty())
        return QFontMetricsF(sans(emptyPt * pxPerPt, false)).height() * leading;
    QTextLayout layout(text.replace(QLatin1Char('\n'), QChar::LineSeparator), sans(biggest * pxPerPt, false));
    layout.setFormats(ranges);
    QTextOption option;
    option.setWrapMode(wrap ? QTextOption::WordWrap : QTextOption::NoWrap);
    option.setAlignment(para.align >= 0 ? Qt::Alignment(para.align) : Qt::AlignLeft);
    layout.setTextOption(option);
    qreal height = 0;
    layout.beginLayout();
    for (QTextLine line = layout.createLine(); line.isValid(); line = layout.createLine()) {
        line.setLineWidth(width);
        line.setPosition(QPointF(0, height));
        height += line.height() * leading;
    }
    layout.endLayout();
    if (painter)
        layout.draw(painter, QPointF(x, y));
    return height;
}

int alignOf(const QString &value)
{
    if (value == u"center" || value == u"ctr")
        return Qt::AlignHCenter;
    if (value == u"right" || value == u"r" || value == u"end")
        return Qt::AlignRight;
    if (value == u"both" || value == u"just" || value == u"distribute")
        return Qt::AlignJustify;
    return Qt::AlignLeft;
}

int boolOf(const QXmlStreamReader &xml)
{
    const QString v = attr(xml, u"val");
    return v.isEmpty() || v == u"1" || v == u"true" || v == u"on" ? 1 : 0;
}

// -- Word: the first page's paragraphs, in their sizes, weights and colors.

struct WordStyle {
    Run run;
    qreal after = -1;
    int align = -1;
    QString basedOn;
};

void readWordRun(QXmlStreamReader &xml, Run &run)
{
    within(xml, [&] {
        const auto n = xml.name();
        if (n == u"b")
            run.bold = boolOf(xml);
        else if (n == u"sz")
            run.pt = number(attr(xml, u"val"), -2) / 2;
        else if (n == u"color" && attr(xml, u"val") != u"auto")
            run.color = hex(attr(xml, u"val"));
        return false;
    });
}

QHash<QString, WordStyle> wordStyles(const QByteArray &bytes, WordStyle *defaults, QString *normal)
{
    QHash<QString, WordStyle> styles;
    QXmlStreamReader xml(bytes);
    while (!xml.atEnd() && !xml.hasError()) {
        if (xml.readNext() != QXmlStreamReader::StartElement)
            continue;
        if (xml.name() == u"docDefaults") {
            within(xml, [&] {
                if (xml.name() == u"rPr") {
                    readWordRun(xml, defaults->run);
                    return true;
                }
                if (xml.name() == u"spacing")
                    defaults->after = number(attr(xml, u"after"), -1);
                return false;
            });
        } else if (xml.name() == u"style" && attr(xml, u"type") == u"paragraph") {
            const QString id = attr(xml, u"styleId");
            if (attr(xml, u"default") == u"1")
                *normal = id;
            WordStyle style;
            within(xml, [&] {
                const auto n = xml.name();
                if (n == u"rPr") {
                    readWordRun(xml, style.run);
                    return true;
                }
                if (n == u"basedOn")
                    style.basedOn = attr(xml, u"val");
                else if (n == u"spacing")
                    style.after = number(attr(xml, u"after"), -1);
                else if (n == u"jc")
                    style.align = alignOf(attr(xml, u"val"));
                return false;
            });
            styles.insert(id, style);
        }
    }
    return styles;
}

QImage word(const KArchiveDirectory *root, const QString &main, int box)
{
    const QByteArray document = entry(root, main);
    if (document.isEmpty())
        return {};
    WordStyle defaults;
    defaults.run.pt = 10; // the spec's, without docDefaults
    defaults.run.bold = 0;
    QString normal;
    const QHash<QString, WordStyle> styles = wordStyles(entry(root, relsOf(root, main).byType.value(QStringLiteral("styles"))), &defaults, &normal);

    // The page and its margins (twips), from the last section's properties.
    auto sectionValue = [&](const char *element, const char *name, double fallback) {
        const qsizetype at = document.lastIndexOf(element);
        if (at < 0)
            return fallback;
        const QByteArray tag = document.mid(at, document.indexOf('>', at) - at);
        const QRegularExpression re(QStringLiteral("\\b(?:w:)?%1=\"(\\d+)\"").arg(QLatin1String(name)));
        const auto match = re.match(QString::fromLatin1(tag));
        return match.hasMatch() ? match.captured(1).toDouble() : fallback;
    };
    const double pageW = sectionValue("<w:pgSz", "w", 12240), pageH = sectionValue("<w:pgSz", "h", 15840);
    const double top = sectionValue("<w:pgMar", "top", 1440), bottom = sectionValue("<w:pgMar", "bottom", 1440);
    const double left = sectionValue("<w:pgMar", "left", 1440), right = sectionValue("<w:pgMar", "right", 1440);
    if (pageW < 1000 || pageH < 1000)
        return {};

    // Its paragraphs, as many as could fill a page.
    QList<Para> paras;
    QXmlStreamReader xml(document);
    bool inPara = false;
    Run run;
    while (!xml.atEnd() && !xml.hasError() && paras.size() < 300) {
        const auto token = xml.readNext();
        if (token == QXmlStreamReader::EndElement && xml.name() == u"p") {
            inPara = false;
            continue;
        }
        if (token != QXmlStreamReader::StartElement)
            continue;
        const auto n = xml.name();
        if (n == u"p") {
            paras.append(Para());
            inPara = true;
        } else if (!inPara) {
            continue;
        } else if (n == u"pPr") {
            Para &para = paras.last();
            within(xml, [&] {
                const auto m = xml.name();
                if (m == u"pStyle")
                    para.style = attr(xml, u"val");
                else if (m == u"spacing") {
                    para.after = number(attr(xml, u"after"), -1);
                    para.before = number(attr(xml, u"before"), -1);
                } else if (m == u"jc")
                    para.align = alignOf(attr(xml, u"val"));
                else if (m == u"rPr") {
                    xml.skipCurrentElement();
                    return true;
                }
                return false;
            });
        } else if (n == u"r") {
            run = {};
        } else if (n == u"rPr") {
            readWordRun(xml, run);
        } else if (n == u"t") {
            Run piece = run;
            piece.text = xml.readElementText();
            paras.last().runs.append(piece);
        } else if (n == u"tab") {
            Run piece = run;
            piece.text = QStringLiteral("    ");
            paras.last().runs.append(piece);
        } else if (n == u"br" || n == u"cr") {
            Run piece = run;
            piece.text = QStringLiteral("\n");
            paras.last().runs.append(piece);
        } else if (n == u"drawing" || n == u"pict" || n == u"instrText" || n == u"delText" || n == u"footnoteReference") {
            xml.skipCurrentElement();
        }
    }

    const int height = std::max(512, std::min(2 * box, 1024)), width = qRound(height * pageW / pageH);
    QImage page(width, height, QImage::Format_ARGB32_Premultiplied);
    page.fill(Qt::white);
    QPainter painter(&page);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::TextAntialiasing);
    const double k = height / pageH; // px a twip
    const qreal x = left * k, textWidth = (pageW - left - right) * k, end = height - bottom * k;
    qreal y = top * k;
    for (const Para &para : paras) {
        // Its style's run and spacing, through what each is based on;
        // Word's own for the usual headings when there are no styles.
        WordStyle style = defaults;
        QStringList chain;
        for (QString id = para.style.isEmpty() ? normal : para.style; !id.isEmpty() && chain.size() < 8 && !chain.contains(id);) {
            chain.prepend(id);
            id = styles.value(id).basedOn;
        }
        for (const QString &id : chain) {
            const WordStyle s = styles.value(id);
            if (s.run.pt > 0)
                style.run.pt = s.run.pt;
            if (s.run.bold >= 0)
                style.run.bold = s.run.bold;
            if (s.run.color.isValid())
                style.run.color = s.run.color;
            if (s.after >= 0)
                style.after = s.after;
            if (s.align >= 0)
                style.align = s.align;
        }
        if (!styles.contains(para.style)) {
            if (para.style == u"Title")
                style.run.pt = 28;
            else if (para.style == u"Heading1")
                style.run = {QString(), 16, 0, QColor(0x2f, 0x54, 0x96)};
            else if (para.style == u"Heading2")
                style.run = {QString(), 13, 0, QColor(0x2f, 0x54, 0x96)};
        }
        Para shown = para;
        if (shown.align < 0)
            shown.align = style.align;
        if (para.before > 0)
            y += para.before * k;
        y += layOut(&painter, shown, x, y, textWidth, 20 * k, style.run, 1.08);
        y += (para.after >= 0 ? para.after : std::max<qreal>(style.after, 0)) * k;
        if (y > end)
            break;
    }
    painter.end();
    return fit(page, box);
}

// -- Excel: the first sheet's top-left cells on a page, as it would print.

QImage excel(const KArchiveDirectory *root, const QString &main, int box)
{
    const Rels workbookRels = relsOf(root, main);
    QString sheetPath;
    {
        QXmlStreamReader xml(entry(root, main));
        while (!xml.atEnd() && !xml.hasError() && sheetPath.isEmpty())
            if (xml.readNext() == QXmlStreamReader::StartElement && xml.name() == u"sheet")
                sheetPath = workbookRels.byId.value(nsAttr(xml, u"id"));
    }
    const QByteArray sheet = entry(root, sheetPath);
    if (sheet.isEmpty())
        return {};

    QStringList strings;
    {
        QXmlStreamReader xml(entry(root, workbookRels.byType.value(QStringLiteral("sharedStrings"))));
        while (!xml.atEnd() && !xml.hasError() && strings.size() < 100000) {
            if (xml.readNext() != QXmlStreamReader::StartElement || xml.name() != u"si")
                continue;
            QString text;
            within(xml, [&] {
                if (xml.name() == u"t") {
                    text += xml.readElementText();
                    return true;
                }
                if (xml.name() == u"rPh") { // phonetic runs
                    xml.skipCurrentElement();
                    return true;
                }
                return false;
            });
            strings.append(text);
        }
    }

    // The bold and the color of each cell format's font.
    QList<Run> fonts, formats;
    {
        QXmlStreamReader xml(entry(root, workbookRels.byType.value(QStringLiteral("styles"))));
        while (!xml.atEnd() && !xml.hasError()) {
            if (xml.readNext() != QXmlStreamReader::StartElement)
                continue;
            if (xml.name() == u"fonts") {
                within(xml, [&] {
                    if (xml.name() != u"font")
                        return false;
                    Run font;
                    font.bold = 0;
                    within(xml, [&] {
                        if (xml.name() == u"b")
                            font.bold = boolOf(xml);
                        else if (xml.name() == u"sz")
                            font.pt = number(attr(xml, u"val"), -1);
                        else if (xml.name() == u"color" && !attr(xml, u"rgb").isEmpty())
                            font.color = hex(attr(xml, u"rgb"));
                        return false;
                    });
                    fonts.append(font);
                    return true;
                });
            } else if (xml.name() == u"cellXfs") {
                within(xml, [&] {
                    if (xml.name() == u"xf")
                        formats.append(fonts.value(attr(xml, u"fontId").toInt()));
                    return false;
                });
            }
        }
    }

    // The cells, by row and column, with the columns' widths (characters)
    // and the rows' heights (points).
    struct Cell {
        int row, column;
        QString text;
        bool numeric;
        Run font;
    };
    QList<Cell> cells;
    QHash<int, double> widths, heights;
    double defaultWidth = 8.43, defaultHeight = 15;
    auto columnOf = [](QStringView ref) {
        int column = 0;
        for (QChar c : ref) {
            if (!c.isLetter())
                break;
            column = column * 26 + (c.toUpper().unicode() - 'A' + 1);
        }
        return column - 1;
    };
    {
        QXmlStreamReader xml(sheet);
        int row = 0;
        while (!xml.atEnd() && !xml.hasError() && row < 80 && cells.size() < 2000) {
            if (xml.readNext() != QXmlStreamReader::StartElement)
                continue;
            const auto n = xml.name();
            if (n == u"sheetFormatPr") {
                defaultHeight = number(attr(xml, u"defaultRowHeight"), 15);
                defaultWidth = number(attr(xml, u"defaultColWidth"), number(attr(xml, u"baseColWidth"), 8) + 0.43);
            } else if (n == u"col") {
                for (int c = attr(xml, u"min").toInt(); c <= std::min(attr(xml, u"max").toInt(), 64); ++c)
                    widths.insert(c - 1, number(attr(xml, u"width"), defaultWidth));
            } else if (n == u"row") {
                row = attr(xml, u"r").toInt();
                if (!attr(xml, u"ht").isEmpty())
                    heights.insert(row - 1, number(attr(xml, u"ht"), defaultHeight));
            } else if (n == u"c") {
                Cell cell{row - 1, columnOf(attr(xml, u"r")), {}, false, formats.value(attr(xml, u"s").toInt())};
                const QString type = attr(xml, u"t");
                within(xml, [&] {
                    if (xml.name() == u"v" || xml.name() == u"t") {
                        cell.text += xml.readElementText();
                        return true;
                    }
                    return false;
                });
                if (type == u"s")
                    cell.text = strings.value(cell.text.toInt());
                else if (type == u"b")
                    cell.text = cell.text == u"1" ? QStringLiteral("TRUE") : QStringLiteral("FALSE");
                else if (type.isEmpty() || type == u"n") {
                    bool ok = false;
                    const double value = cell.text.toDouble(&ok);
                    cell.numeric = ok;
                    if (ok)
                        cell.text = QString::number(value, 'g', 10);
                }
                if (cell.row >= 0 && cell.column >= 0 && cell.column < 64 && !cell.text.isEmpty())
                    cells.append(cell);
            }
        }
    }
    if (cells.isEmpty())
        return {};

    // Quick Look's sheet: the cells used, in Excel's widths (px at 96 dpi)
    // and rows a quarter shorter (as tall as their text), across a portrait
    // page with 5% margins, without gridlines.
    int lastRow = 0, lastColumn = 0;
    for (const Cell &cell : cells) {
        lastRow = std::max(lastRow, cell.row);
        lastColumn = std::max(lastColumn, cell.column);
    }
    auto columnWidth = [&](int column) { return widths.value(column, defaultWidth) * 7 + 5; };
    auto rowHeight = [&](int row) { return heights.value(row, defaultHeight) * 96 / 72 * 0.75; };
    double tableWidth = 0;
    for (int c = 0; c <= lastColumn; ++c)
        tableWidth += columnWidth(c);
    const double pageWidth = std::max(320.0, tableWidth / 0.9);
    const int height = std::max(512, std::min(2 * box, 1024)), width = qRound(height * 8.5 / 11);
    const double k = width / pageWidth;
    QImage page(width, height, QImage::Format_ARGB32_Premultiplied);
    page.fill(Qt::white);
    QPainter painter(&page);
    painter.setRenderHint(QPainter::TextAntialiasing);
    const double x0 = pageWidth * 0.05 * k, y0 = pageWidth * 0.035 * k, right = width - x0, bottom = height - y0;
    auto columnX = [&](int column) {
        double x = x0;
        for (int c = 0; c < column; ++c)
            x += columnWidth(c) * k;
        return x;
    };
    auto rowY = [&](int row) {
        double y = y0;
        for (int r = 0; r < row; ++r)
            y += rowHeight(r) * k;
        return y;
    };
    for (const Cell &cell : cells) {
        const QRectF rect(columnX(cell.column), rowY(cell.row), columnWidth(cell.column) * k, rowHeight(cell.row) * k);
        if (rect.left() >= right || rect.top() >= bottom)
            continue;
        painter.setFont(sans((cell.font.pt > 0 ? cell.font.pt : 11) * 96 / 72 * k, cell.font.bold == 1));
        painter.setPen(cell.font.color.isValid() ? cell.font.color : QColor(Qt::black));
        painter.drawText(rect.adjusted(3 * k, 0, -3 * k, 0), Qt::AlignVCenter | (cell.numeric ? Qt::AlignRight : Qt::AlignLeft), cell.text);
    }
    painter.end();
    return fit(page, box);
}

// -- PowerPoint: the first slide, its background and shapes, with what the
// layout and master underneath give it.

struct Deck {
    QHash<QString, QColor> scheme; // dk1, lt1, accent1…
    QHash<QString, QString> map;   // bg1 → lt1, tx1 → dk1…

    // A scheme color by its name or its role (the master's color map comes
    // after its shapes; until then, the usual one).
    QColor scheme_(const QString &name) const
    {
        QString mapped = map.value(name);
        if (mapped.isEmpty())
            mapped = name == u"bg1" ? QStringLiteral("lt1") : name == u"tx1" ? QStringLiteral("dk1")
                : name == u"bg2" ? QStringLiteral("lt2") : name == u"tx2" ? QStringLiteral("dk2") : name;
        return scheme.value(mapped);
    }
};

// A color element's color (srgbClr, schemeClr, sysClr, prstClr) with its
// luminance and alpha changes; xml is at the element holding it.
QColor readColor(QXmlStreamReader &xml, const Deck &deck)
{
    QColor color;
    within(xml, [&] {
        const auto n = xml.name();
        if (n == u"srgbClr")
            color = hex(attr(xml, u"val"));
        else if (n == u"schemeClr")
            color = deck.scheme_(attr(xml, u"val"));
        else if (n == u"sysClr")
            color = hex(attr(xml, u"lastClr"));
        else if (n == u"prstClr")
            color = QColor::fromString(attr(xml, u"val"));
        else if (color.isValid() && (n == u"lumMod" || n == u"lumOff" || n == u"alpha" || n == u"shade" || n == u"tint")) {
            const double v = number(attr(xml, u"val")) / 100000;
            float h, s, l, a;
            color.getHslF(&h, &s, &l, &a);
            if (n == u"lumMod")
                l *= v;
            else if (n == u"lumOff")
                l += v;
            else if (n == u"alpha")
                a = v;
            else if (n == u"shade")
                l *= v;
            else
                l = l + (1 - l) * (1 - v);
            color = QColor::fromHslF(h, s, std::clamp<float>(l, 0, 1), std::clamp<float>(a, 0, 1));
        }
        return false;
    });
    return color;
}

struct Fill {
    QColor color;
    QGradientStops stops;
    double angle = 90; // degrees, as DrawingML's lin
    QString image;     // a blip's relationship id
    bool none = false;
    bool set() const { return none || color.isValid() || !stops.isEmpty() || !image.isEmpty(); }
};

// A fill element (solidFill, gradFill, blipFill, noFill); xml is at it.
Fill readFill(QXmlStreamReader &xml, const Deck &deck)
{
    Fill fill;
    const auto n = xml.name();
    if (n == u"noFill") {
        fill.none = true;
        xml.skipCurrentElement();
    } else if (n == u"solidFill") {
        fill.color = readColor(xml, deck);
    } else if (n == u"gradFill") {
        within(xml, [&] {
            if (xml.name() == u"gs") {
                const double at = number(attr(xml, u"pos")) / 100000;
                fill.stops.append(QGradientStop(at, readColor(xml, deck)));
                return true;
            }
            if (xml.name() == u"lin")
                fill.angle = number(attr(xml, u"ang")) / 60000;
            return false;
        });
        std::sort(fill.stops.begin(), fill.stops.end(), [](const auto &a, const auto &b) { return a.first < b.first; });
    } else if (n == u"blipFill") {
        within(xml, [&] {
            if (xml.name() == u"blip")
                fill.image = nsAttr(xml, u"embed");
            return false;
        });
    } else {
        xml.skipCurrentElement();
    }
    return fill;
}

bool isFill(QStringView n)
{
    return n == u"noFill" || n == u"solidFill" || n == u"gradFill" || n == u"blipFill";
}

// Text defaults: a list style's first level, or the master's text styles.
struct TextDefaults {
    qreal pt = -1;
    int bold = -1;
    QColor color;
    int align = -1;
};

TextDefaults readLevel1(QXmlStreamReader &xml, const Deck &deck)
{
    TextDefaults d;
    within(xml, [&] {
        if (xml.name() != u"lvl1pPr") {
            if (xml.name().startsWith(u"lvl")) {
                xml.skipCurrentElement();
                return true;
            }
            return false;
        }
        if (!attr(xml, u"algn").isEmpty())
            d.align = alignOf(attr(xml, u"algn"));
        within(xml, [&] {
            if (xml.name() == u"defRPr") {
                if (!attr(xml, u"sz").isEmpty())
                    d.pt = number(attr(xml, u"sz")) / 100;
                if (!attr(xml, u"b").isEmpty())
                    d.bold = attr(xml, u"b") == u"1" || attr(xml, u"b") == u"true";
                within(xml, [&] {
                    if (xml.name() == u"solidFill") {
                        d.color = readColor(xml, deck);
                        return true;
                    }
                    return false;
                });
                return true;
            }
            return false;
        });
        return true;
    });
    return d;
}

struct Shape {
    bool placeholder = false;
    QString phType;
    QString phIdx;
    bool hasBox = false;
    QRectF box; // EMU
    Fill fill, line;
    QColor styleFill, styleText;
    QString geometry;
    bool picture = false;
    QString image;
    QString anchor;
    bool wrap = true;
    double fontScale = 1;
    double insets[4] = {91440, 45720, 91440, 45720}; // left, top, right, bottom
    TextDefaults defaults;
    QList<Para> paras;
};

// Maps a group's child coordinates to the slide's.
struct Transform {
    double ax = 1, bx = 0, ay = 1, by = 0;
    QRectF map(const QRectF &r) const { return QRectF(ax * r.x() + bx, ay * r.y() + by, ax * r.width(), ay * r.height()); }
};

void readXfrm(QXmlStreamReader &xml, QRectF *box, QRectF *child)
{
    QPointF off, chOff;
    QSizeF ext, chExt;
    while (xml.readNextStartElement()) {
        const auto n = xml.name();
        if (n == u"off")
            off = QPointF(number(attr(xml, u"x")), number(attr(xml, u"y")));
        else if (n == u"ext")
            ext = QSizeF(number(attr(xml, u"cx")), number(attr(xml, u"cy")));
        else if (n == u"chOff")
            chOff = QPointF(number(attr(xml, u"x")), number(attr(xml, u"y")));
        else if (n == u"chExt")
            chExt = QSizeF(number(attr(xml, u"cx")), number(attr(xml, u"cy")));
        xml.skipCurrentElement();
    }
    *box = QRectF(off, ext);
    if (child)
        *child = QRectF(chOff, chExt);
}

void readText(QXmlStreamReader &xml, Shape &shape, const Deck &deck)
{
    within(xml, [&] {
        const auto n = xml.name();
        if (n == u"bodyPr") {
            if (!attr(xml, u"anchor").isEmpty())
                shape.anchor = attr(xml, u"anchor");
            if (attr(xml, u"wrap") == u"none")
                shape.wrap = false;
            const char16_t *names[] = {u"lIns", u"tIns", u"rIns", u"bIns"};
            for (int i = 0; i < 4; ++i)
                if (!attr(xml, names[i]).isEmpty())
                    shape.insets[i] = number(attr(xml, names[i]));
            within(xml, [&] {
                if (xml.name() == u"normAutofit" && !attr(xml, u"fontScale").isEmpty())
                    shape.fontScale = number(attr(xml, u"fontScale"), 100000) / 100000;
                return false;
            });
            return true;
        }
        if (n == u"lstStyle") {
            shape.defaults = readLevel1(xml, deck);
            return true;
        }
        if (n != u"p")
            return false;
        Para para;
        within(xml, [&] {
            const auto m = xml.name();
            if (m == u"pPr") {
                if (!attr(xml, u"algn").isEmpty())
                    para.align = alignOf(attr(xml, u"algn"));
                xml.skipCurrentElement();
                return true;
            }
            if (m == u"endParaRPr") {
                para.endPt = number(attr(xml, u"sz"), -100) / 100;
                xml.skipCurrentElement();
                return true;
            }
            if (m == u"br") {
                Run run;
                run.text = QStringLiteral("\n");
                para.runs.append(run);
                xml.skipCurrentElement();
                return true;
            }
            if (m != u"r" && m != u"fld")
                return false;
            Run run;
            within(xml, [&] {
                if (xml.name() == u"rPr") {
                    if (!attr(xml, u"sz").isEmpty())
                        run.pt = number(attr(xml, u"sz")) / 100;
                    if (!attr(xml, u"b").isEmpty())
                        run.bold = attr(xml, u"b") == u"1" || attr(xml, u"b") == u"true";
                    within(xml, [&] {
                        if (xml.name() == u"solidFill") {
                            run.color = readColor(xml, deck);
                            return true;
                        }
                        if (xml.name() == u"ln" || xml.name() == u"effectLst" || xml.name() == u"highlight") {
                            xml.skipCurrentElement();
                            return true;
                        }
                        return false;
                    });
                    return true;
                }
                if (xml.name() == u"t") {
                    run.text += xml.readElementText();
                    return true;
                }
                return false;
            });
            para.runs.append(run);
            return true;
        });
        shape.paras.append(para);
        return true;
    });
}

Shape readShape(QXmlStreamReader &xml, bool picture, const Deck &deck)
{
    Shape shape;
    shape.picture = picture;
    while (xml.readNextStartElement()) {
        const auto n = xml.name();
        if (n == u"nvSpPr" || n == u"nvPicPr") {
            within(xml, [&] {
                if (xml.name() == u"ph") {
                    shape.placeholder = true;
                    shape.phType = attr(xml, u"type");
                    shape.phIdx = attr(xml, u"idx");
                }
                return false;
            });
        } else if (n == u"spPr") {
            within(xml, [&] {
                const auto m = xml.name();
                if (m == u"xfrm") {
                    readXfrm(xml, &shape.box, nullptr);
                    shape.hasBox = shape.box.width() > 0 && shape.box.height() > 0;
                    return true;
                }
                if (isFill(m)) {
                    shape.fill = readFill(xml, deck);
                    return true;
                }
                if (m == u"ln") {
                    within(xml, [&] {
                        if (isFill(xml.name())) {
                            shape.line = readFill(xml, deck);
                            return true;
                        }
                        return false;
                    });
                    return true;
                }
                if (m == u"prstGeom") {
                    shape.geometry = attr(xml, u"prst");
                    xml.skipCurrentElement();
                    return true;
                }
                if (m == u"extLst" || m == u"custGeom" || m == u"effectLst") {
                    xml.skipCurrentElement();
                    return true;
                }
                return false;
            });
        } else if (n == u"style") {
            within(xml, [&] {
                if (xml.name() == u"fillRef") {
                    const bool used = attr(xml, u"idx") != u"0";
                    const QColor color = readColor(xml, deck);
                    if (used)
                        shape.styleFill = color;
                    return true;
                }
                if (xml.name() == u"fontRef") {
                    shape.styleText = readColor(xml, deck);
                    return true;
                }
                if (xml.name() == u"lnRef" || xml.name() == u"effectRef") {
                    xml.skipCurrentElement();
                    return true;
                }
                return false;
            });
        } else if (n == u"txBody") {
            readText(xml, shape, deck);
        } else if (n == u"blipFill") {
            shape.image = readFill(xml, deck).image;
        } else {
            xml.skipCurrentElement();
        }
    }
    return shape;
}

void readTree(QXmlStreamReader &xml, QList<Shape> &shapes, const Transform &outer, const Deck &deck)
{
    Transform t = outer;
    while (xml.readNextStartElement()) {
        const auto n = xml.name();
        if (n == u"grpSpPr") {
            within(xml, [&] {
                if (xml.name() == u"xfrm") {
                    QRectF box, child;
                    readXfrm(xml, &box, &child);
                    if (child.width() > 0 && child.height() > 0) {
                        const double ax = box.width() / child.width(), ay = box.height() / child.height();
                        const double bx = box.x() - child.x() * ax, by = box.y() - child.y() * ay;
                        t = {outer.ax * ax, outer.ax * bx + outer.bx, outer.ay * ay, outer.ay * by + outer.by};
                    }
                    return true;
                }
                return false;
            });
        } else if (n == u"sp" || n == u"pic") {
            Shape shape = readShape(xml, n == u"pic", deck);
            if (shape.hasBox)
                shape.box = t.map(shape.box);
            shapes.append(shape);
            if (shapes.size() > 400)
                return;
        } else if (n == u"grpSp") {
            readTree(xml, shapes, t, deck);
        } else {
            xml.skipCurrentElement();
        }
    }
}

// A slide, layout or master: its background, shapes, and (for a master)
// its text styles and color map.
struct Sheet {
    QString path;
    Rels rels;
    Fill background;
    QList<Shape> shapes;
    bool showMaster = true;
    TextDefaults title, body, other;
};

Sheet readSheet(const KArchiveDirectory *root, const QString &path, Deck &deck, bool master)
{
    Sheet sheet;
    sheet.path = path;
    sheet.rels = relsOf(root, path);
    QXmlStreamReader xml(entry(root, path));
    while (!xml.atEnd() && !xml.hasError()) {
        if (xml.readNext() != QXmlStreamReader::StartElement)
            continue;
        const auto n = xml.name();
        if (n == u"sld" || n == u"sldLayout")
            sheet.showMaster = attr(xml, u"showMasterSp") != u"0";
        else if (n == u"clrMap" && master)
            for (const QXmlStreamAttribute &a : xml.attributes())
                deck.map.insert(a.name().toString(), a.value().toString());
        else if (n == u"bg") {
            within(xml, [&] {
                if (isFill(xml.name())) {
                    sheet.background = readFill(xml, deck);
                    return true;
                }
                if (xml.name() == u"bgRef") {
                    sheet.background.color = readColor(xml, deck);
                    return true;
                }
                return false;
            });
        } else if (n == u"spTree") {
            readTree(xml, sheet.shapes, {}, deck);
        } else if (n == u"txStyles") {
            within(xml, [&] {
                const auto m = xml.name();
                if (m == u"titleStyle" || m == u"bodyStyle" || m == u"otherStyle") {
                    (m == u"titleStyle" ? sheet.title : m == u"bodyStyle" ? sheet.body : sheet.other) = readLevel1(xml, deck);
                    return true;
                }
                return false;
            });
        }
    }
    return sheet;
}

void readTheme(const QByteArray &bytes, Deck &deck)
{
    QXmlStreamReader xml(bytes);
    while (!xml.atEnd() && !xml.hasError()) {
        if (xml.readNext() != QXmlStreamReader::StartElement || xml.name() != u"clrScheme")
            continue;
        while (xml.readNextStartElement()) {
            const QString name = xml.name().toString();
            Deck none;
            deck.scheme.insert(name, readColor(xml, none));
        }
        return;
    }
}

QString baseType(const QString &type)
{
    if (type == u"ctrTitle")
        return QStringLiteral("title");
    if (type.isEmpty() || type == u"subTitle" || type == u"obj")
        return QStringLiteral("body");
    return type;
}

const Shape *matching(const Sheet &sheet, const Shape &shape)
{
    if (!shape.phIdx.isEmpty())
        for (const Shape &s : sheet.shapes)
            if (s.placeholder && s.phIdx == shape.phIdx)
                return &s;
    for (const Shape &s : sheet.shapes)
        if (s.placeholder && s.phType == shape.phType)
            return &s;
    for (const Shape &s : sheet.shapes)
        if (s.placeholder && baseType(s.phType) == baseType(shape.phType))
            return &s;
    return nullptr;
}

QImage slides(const KArchiveDirectory *root, const QString &main, int box)
{
    const Rels presentationRels = relsOf(root, main);
    QString slidePath;
    QSizeF size(9144000, 6858000);
    {
        QXmlStreamReader xml(entry(root, main));
        while (!xml.atEnd() && !xml.hasError()) {
            if (xml.readNext() != QXmlStreamReader::StartElement)
                continue;
            if (xml.name() == u"sldId" && slidePath.isEmpty())
                slidePath = presentationRels.byId.value(nsAttr(xml, u"id"));
            else if (xml.name() == u"sldSz")
                size = QSizeF(number(attr(xml, u"cx"), 9144000), number(attr(xml, u"cy"), 6858000));
        }
    }
    if (slidePath.isEmpty() || size.width() <= 0 || size.height() <= 0)
        return {};
    Deck deck;
    const Rels slideRels = relsOf(root, slidePath);
    const QString layoutPath = slideRels.byType.value(QStringLiteral("slideLayout"));
    const QString masterPath = relsOf(root, layoutPath).byType.value(QStringLiteral("slideMaster"));
    readTheme(entry(root, relsOf(root, masterPath).byType.value(QStringLiteral("theme"))), deck);
    const Sheet master = readSheet(root, masterPath, deck, true);
    const Sheet layout = readSheet(root, layoutPath, deck, false);
    const Sheet slide = readSheet(root, slidePath, deck, false);

    const int width = std::max(512, std::min(2 * box, 1024)), height = qRound(width * size.height() / size.width());
    const double k = width / size.width(); // px an EMU
    QImage image(width, height, QImage::Format_ARGB32_Premultiplied);
    image.fill(Qt::white);
    QPainter painter(&image);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    painter.setRenderHint(QPainter::TextAntialiasing);

    auto picture = [&](const Sheet &sheet, const QString &id) {
        QImage picture;
        const QByteArray bytes = entry(root, sheet.rels.byId.value(id));
        if (!bytes.isEmpty())
            picture = decode(bytes, width);
        return picture;
    };
    auto brush = [&](const Fill &fill, const QRectF &rect) -> QBrush {
        if (!fill.stops.isEmpty()) {
            const double a = qDegreesToRadians(fill.angle);
            const QPointF c = rect.center(), d(std::cos(a) * rect.width() / 2, std::sin(a) * rect.height() / 2);
            QLinearGradient gradient(c - d, c + d);
            gradient.setStops(fill.stops);
            return gradient;
        }
        return fill.color;
    };
    auto paintFill = [&](const Sheet &sheet, const Fill &fill, const QRectF &rect, const QString &geometry) {
        if (!fill.image.isEmpty()) {
            const QImage p = picture(sheet, fill.image);
            if (!p.isNull())
                painter.drawImage(rect, p);
            return;
        }
        painter.setPen(Qt::NoPen);
        painter.setBrush(brush(fill, rect));
        if (geometry == u"ellipse")
            painter.drawEllipse(rect);
        else if (geometry == u"roundRect")
            painter.drawRoundedRect(rect, std::min(rect.width(), rect.height()) / 6, std::min(rect.width(), rect.height()) / 6);
        else
            painter.drawRect(rect);
    };

    // The background: the slide's, else its layout's, else the master's.
    const Sheet *withBackground = slide.background.set() ? &slide : layout.background.set() ? &layout : master.background.set() ? &master : nullptr;
    if (withBackground && !withBackground->background.none)
        paintFill(*withBackground, withBackground->background, QRectF(0, 0, width, height), {});

    auto draw = [&](const Sheet &sheet, const Shape &shape, bool placeholders) {
        if (shape.placeholder && !placeholders)
            return;
        // A placeholder's box, anchor and text defaults come from the
        // layout's like it, then the master's.
        const Shape *fromLayout = shape.placeholder && &sheet == &slide ? matching(layout, shape) : nullptr;
        const Shape *fromMaster = shape.placeholder ? matching(master, fromLayout ? *fromLayout : shape) : nullptr;
        QRectF rect = shape.box;
        if (!shape.hasBox)
            rect = fromLayout && fromLayout->hasBox ? fromLayout->box : fromMaster && fromMaster->hasBox ? fromMaster->box : QRectF();
        if (rect.isEmpty())
            return;
        const QRectF px(rect.x() * k, rect.y() * k, rect.width() * k, rect.height() * k);
        if (shape.picture) {
            const QImage p = picture(sheet, shape.image);
            if (!p.isNull())
                painter.drawImage(px, p);
            return;
        }
        if (shape.fill.set() && !shape.fill.none)
            paintFill(sheet, shape.fill, px, shape.geometry);
        else if (!shape.fill.set() && shape.styleFill.isValid())
            paintFill(sheet, Fill{shape.styleFill}, px, shape.geometry);
        if (shape.line.color.isValid()) {
            painter.setPen(QPen(shape.line.color, std::max(1.0, 12700 * k)));
            painter.setBrush(Qt::NoBrush);
            painter.drawRect(px);
        }
        if (shape.paras.isEmpty())
            return;
        // The text's defaults, the nearest first.
        const QString type = baseType(shape.phType);
        const TextDefaults &styled = !shape.placeholder ? master.other : type == u"title" ? master.title : master.body;
        Run base;
        base.pt = 18;
        base.bold = 0;
        base.color = shape.styleText.isValid() ? shape.styleText : deck.scheme_(QStringLiteral("tx1"));
        int align = -1;
        QString anchor = type == u"title" ? QStringLiteral("ctr") : QStringLiteral("t");
        for (const TextDefaults *d : {&styled, fromMaster ? &fromMaster->defaults : nullptr, fromLayout ? &fromLayout->defaults : nullptr, &shape.defaults}) {
            if (!d)
                continue;
            if (d->pt > 0)
                base.pt = d->pt;
            if (d->bold >= 0)
                base.bold = d->bold;
            if (d->color.isValid())
                base.color = d->color;
            if (d->align >= 0)
                align = d->align;
        }
        for (const Shape *s : {fromMaster, fromLayout, &shape})
            if (s && !s->anchor.isEmpty())
                anchor = s->anchor;
        if (!base.color.isValid())
            base.color = Qt::black;
        base.pt *= shape.fontScale;
        const QRectF inner = px.adjusted(shape.insets[0] * k, shape.insets[1] * k, -shape.insets[2] * k, -shape.insets[3] * k);
        QList<Para> paras = shape.paras;
        for (Para &para : paras) {
            if (para.align < 0)
                para.align = align;
            for (Run &run : para.runs)
                if (run.pt > 0)
                    run.pt *= shape.fontScale;
        }
        const qreal pxPerPt = 12700 * k;
        qreal total = 0;
        for (const Para &para : paras)
            total += layOut(nullptr, para, 0, 0, inner.width(), pxPerPt, base, 1.0, shape.wrap);
        qreal y = anchor == u"ctr" ? inner.top() + (inner.height() - total) / 2 : anchor == u"b" ? inner.bottom() - total : inner.top();
        for (const Para &para : paras)
            y += layOut(&painter, para, inner.left(), y, inner.width(), pxPerPt, base, 1.0, shape.wrap);
    };
    if (slide.showMaster && layout.showMaster)
        for (const Shape &shape : master.shapes)
            draw(master, shape, false);
    for (const Shape &shape : layout.shapes)
        draw(layout, shape, false);
    for (const Shape &shape : slide.shapes)
        draw(slide, shape, true);
    painter.end();
    return fit(image, box);
}

} // namespace

QImage Previews::video(QFile &file, int box)
{
    if (ffmpeg().isEmpty())
        return {};
    const QByteArray filter = QStringLiteral("thumbnail=24,scale=%1:%1:force_original_aspect_ratio=decrease").arg(box).toLatin1();
    // From a second in; a clip shorter than that, from its start.
    for (const char *at : {"1", "0"}) {
        ::lseek(file.handle(), 0, SEEK_SET);
        const QByteArray png = run(ffmpeg(),
                                   {"-nostdin", "-v", "error", "-threads", "1", "-ss", at, "-i", "fd:", "-an", "-sn", "-vf", filter,
                                    "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "-"},
                                   file.handle(), std::chrono::seconds(10));
        if (!png.isEmpty())
            return fit(QImage::fromData(png, "PNG"), box);
    }
    return {};
}

QImage Previews::font(QFile &file, int box)
{
    if (file.size() > (64 << 20))
        return {};
    const QByteArray data = file.readAll();
    FT_Library library = nullptr;
    if (FT_Init_FreeType(&library) != 0)
        return {};
    const std::unique_ptr<std::remove_pointer_t<FT_Library>, decltype(&FT_Done_FreeType)> done(library, &FT_Done_FreeType);
    FT_Face face = nullptr; // freed with the library
    if (FT_New_Memory_Face(library, reinterpret_cast<const FT_Byte *>(data.constData()), FT_Long(data.size()), 0, &face) != 0)
        return {};
    // A variable font as its Regular, the named instance nearest weight
    // 400, as Finder shows it (Inter's default instance is its Thin).
    FT_MM_Var *axes = nullptr;
    if (FT_HAS_MULTIPLE_MASTERS(face) && FT_Get_MM_Var(face, &axes) == 0) {
        int weight = -1;
        for (FT_UInt a = 0; a < axes->num_axis; ++a)
            if (axes->axis[a].tag == FT_MAKE_TAG('w', 'g', 'h', 't'))
                weight = int(a);
        FT_UInt best = 0;
        double nearest = 1e9;
        for (FT_UInt i = 0; weight >= 0 && i < axes->num_namedstyles; ++i) {
            const double distance = std::abs(axes->namedstyle[i].coords[weight] / 65536.0 - 400);
            if (distance < nearest) {
                nearest = distance;
                best = i + 1;
            }
        }
        if (best)
            FT_Set_Named_Instance(face, best);
        FT_Done_MM_Var(library, axes);
    }
    if (FT_Set_Char_Size(face, 0, 1000 * 64, 72, 72) != 0)
        return {};
    // A character's outline at 1000 px, the baseline at 0 and up negative,
    // as Qt draws.
    auto outline = [face](FT_ULong code, qreal *advance) {
        QPainterPath path;
        if (FT_Get_Char_Index(face, code) == 0 || FT_Load_Char(face, code, FT_LOAD_NO_HINTING | FT_LOAD_NO_BITMAP) != 0
            || face->glyph->format != FT_GLYPH_FORMAT_OUTLINE)
            return path;
        FT_Outline_Funcs funcs{};
        funcs.move_to = [](const FT_Vector *to, void *user) {
            auto *p = static_cast<QPainterPath *>(user);
            p->closeSubpath();
            p->moveTo(to->x / 64.0, -to->y / 64.0);
            return 0;
        };
        funcs.line_to = [](const FT_Vector *to, void *user) {
            static_cast<QPainterPath *>(user)->lineTo(to->x / 64.0, -to->y / 64.0);
            return 0;
        };
        funcs.conic_to = [](const FT_Vector *c, const FT_Vector *to, void *user) {
            static_cast<QPainterPath *>(user)->quadTo(c->x / 64.0, -c->y / 64.0, to->x / 64.0, -to->y / 64.0);
            return 0;
        };
        funcs.cubic_to = [](const FT_Vector *c1, const FT_Vector *c2, const FT_Vector *to, void *user) {
            static_cast<QPainterPath *>(user)->cubicTo(c1->x / 64.0, -c1->y / 64.0, c2->x / 64.0, -c2->y / 64.0, to->x / 64.0, -to->y / 64.0);
            return 0;
        };
        FT_Outline_Decompose(&face->glyph->outline, &funcs, &path);
        path.closeSubpath();
        path.setFillRule(Qt::WindingFill); // TrueType's: overlapping contours stay filled
        if (advance)
            *advance = face->glyph->advance.x / 64.0;
        return path;
    };
    qreal advance = 0;
    QPainterPath ink = outline('A', &advance);
    const QPainterPath a = outline('a', nullptr);
    if (ink.isEmpty() || a.isEmpty())
        return {};
    ink.addPath(a.translated(advance, 0));
    const QRectF bounds = ink.boundingRect();
    if (bounds.width() <= 0 || bounds.top() >= 0)
        return {};
    const QPainterPath x = outline('x', nullptr);
    const qreal xHeight = x.isEmpty() ? -bounds.top() * 0.7 : -x.boundingRect().top();
    // Finder's, measured on a 112-px tile: the letters 95 px across,
    // centred, their tops 9 px under the tile's top, the baseline 8 px over
    // its bottom; so the tile is as tall as the font's capitals make it.
    const qreal width = std::max(box, 256);
    const qreal scale = width * 95 / 112 / bounds.width();
    const qreal baseline = width * 9 / 112 - bounds.top() * scale;
    const int height = qRound(baseline + width * 8 / 112);
    QImage tile(int(width), height, QImage::Format_ARGB32_Premultiplied);
    tile.fill(Qt::white);
    QPainter painter(&tile);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.save();
    painter.translate((width - bounds.width() * scale) / 2 - bounds.left() * scale, baseline);
    painter.scale(scale, scale);
    painter.fillPath(ink, Qt::black);
    painter.restore();
    // The guide lines, a hairline each at Finder's 2x.
    const qreal line = width / 112;
    painter.fillRect(QRectF(0, baseline - xHeight * scale - line, width, line), Qt::black);
    painter.fillRect(QRectF(0, baseline - line, width, line), Qt::black);
    painter.end();
    return fit(tile, box);
}

QImage Previews::audioCover(QFile &file, int box)
{
    const int fd = ::dup(file.handle());
    if (fd < 0)
        return {};
    ::lseek(fd, 0, SEEK_SET);
    TagLib::FileStream stream(fd, true); // closes it
    if (!stream.isOpen()) {
        ::close(fd);
        return {};
    }
    const TagLib::FileRef ref(&stream, false);
    if (ref.isNull())
        return {};
    const TagLib::List<TagLib::VariantMap> pictures = ref.complexProperties("PICTURE");
    if (pictures.isEmpty())
        return {};
    // The front cover, else the first picture.
    TagLib::VariantMap chosen = pictures.front();
    for (const TagLib::VariantMap &picture : pictures)
        if (picture.value("pictureType").toString() == "Front Cover") {
            chosen = picture;
            break;
        }
    const TagLib::ByteVector bytes = chosen.value("data").toByteVector();
    if (bytes.isEmpty())
        return {};
    return decode(QByteArray(bytes.data(), int(bytes.size())), box);
}

QImage Previews::office(QFile &file, const QString &suffix, int box, QString *how)
{
    KZip zip(&file);
    if (!zip.open(QIODevice::ReadOnly))
        return {};
    const KArchiveDirectory *root = zip.directory();
    if (!root)
        return {};
    // The preview saved in it: OpenDocument's Thumbnails/thumbnail.png,
    // Office's docProps/thumbnail.* (a JPEG or PNG; WMF and EMF aren't read).
    const bool odf = suffix.startsWith(QLatin1Char('o')); // odt, ods, odp, ott…
    const Rels package = odf ? Rels() : relsOf(root, QString());
    const QByteArray saved = entry(root, odf ? QStringLiteral("Thumbnails/thumbnail.png") : package.byType.value(QStringLiteral("thumbnail")));
    if (!saved.isEmpty()) {
        const QImage image = decode(saved, box);
        if (!image.isNull()) {
            if (how)
                *how = QStringLiteral("saved");
            return image;
        }
    }
    if (odf)
        return {};
    const QString main = package.byType.value(QStringLiteral("officeDocument"));
    const QString part = main.section(QLatin1Char('/'), 0, 0);
    if (how)
        *how = part == u"word" ? QStringLiteral("word") : part == u"xl" ? QStringLiteral("excel") : QStringLiteral("slides");
    if (part == u"word")
        return word(root, main, box);
    if (part == u"xl")
        return excel(root, main, box);
    if (part == u"ppt")
        return slides(root, main, box);
    return {};
}
