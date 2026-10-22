#include "thumbnailer.h"
#include "previews.h"

#include <QCryptographicHash>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QFontDatabase>
#include <QHash>
#include <QImageReader>
#include <QMimeDatabase>
#include <QMutex>
#include <QPainter>
#include <QPainterPath>
#include <QSet>
#include <QStandardPaths>
#include <QTemporaryFile>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <deque>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

#include <cerrno>
#include <fcntl.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <unistd.h>

namespace {

using namespace std::chrono_literals;

// FILES_TRACE=1 prints each thumbnail made and each pause for the disk.
const bool trace = std::getenv("FILES_TRACE") != nullptr;

double envOr(const char *name, double fallback)
{
    const char *value = std::getenv(name);
    return value ? std::atof(value) : fallback;
}

// The disk counts as under pressure while tasks wait on it more than this
// share of the time (/proc/pressure/io, "some", the last 10 s, in %), and
// as calm again below the second: making waits in between, cached ones
// still show.
const double pauseAbove = envOr("FILES_THUMB_PAUSE", 30);
const double resumeBelow = envOr("FILES_THUMB_RESUME", 15);

// Bigger files are left as their icons.
constexpr qint64 largest = 200LL << 20;

double ioPressure()
{
    FILE *file = std::fopen("/proc/pressure/io", "re");
    if (!file)
        return 0;
    double some = 0;
    if (std::fscanf(file, "some avg10=%lf", &some) != 1)
        some = 0;
    std::fclose(file);
    return some;
}

// The calling thread yields to everything else: nice 10 and idle I/O.
void background()
{
    const auto tid = pid_t(syscall(SYS_gettid));
    setpriority(PRIO_PROCESS, id_t(tid), 10);
    syscall(SYS_ioprio_set, 1 /* IOPRIO_WHO_PROCESS */, tid, 3 << 13 /* IOPRIO_CLASS_IDLE */);
}

// Opens a file to read without marking it read (O_NOATIME, for one's own
// files): a thumbnail mustn't change when the file was last opened.
bool openQuietly(QFile &file, const QString &path)
{
    const QByteArray native = QFile::encodeName(path);
    int fd = ::open(native.constData(), O_RDONLY | O_CLOEXEC | O_NOATIME);
    if (fd < 0 && errno == EPERM)
        fd = ::open(native.constData(), O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return false;
    if (!file.open(fd, QIODevice::ReadOnly, QFileDevice::AutoCloseHandle)) {
        ::close(fd);
        return false;
    }
    return true;
}

enum class Kind { None, Picture, Text, Video, Font, Audio, Office };

// What a name's thumbnail would show, by its extension: a picture Qt reads
// (JPEG, PNG, WebP, HEIF, AVIF, JXL, TIFF, SVG, PDF's first page …), a
// page of its text, a frame of a video, a font's "Aa", an audio file's
// cover, or an office document's first page.
Kind kindOf(const QString &name)
{
    static QMutex lock;
    static QHash<QString, Kind> kinds;
    const qsizetype dot = name.lastIndexOf(QLatin1Char('.'));
    if (dot <= 0)
        return Kind::None;
    const QString ext = name.mid(dot + 1).toLower();
    QMutexLocker locked(&lock);
    if (auto it = kinds.constFind(ext); it != kinds.cend())
        return *it;
    static const QList<QByteArray> pictures = QImageReader::supportedMimeTypes();
    const QMimeType mime = QMimeDatabase().mimeTypeForFile(name, QMimeDatabase::MatchExtension);
    Kind kind = Kind::None;
    if (pictures.contains(mime.name().toLatin1()))
        kind = Kind::Picture;
    else
        for (const QString &alias : mime.aliases())
            if (pictures.contains(alias.toLatin1()))
                kind = Kind::Picture;
    // A page of text, but not a web page's source.
    if (kind == Kind::None && mime.inherits(QStringLiteral("text/plain")) && !mime.inherits(QStringLiteral("text/html")))
        kind = Kind::Text;
    const QString type = mime.name();
    if (kind != Kind::None) {
    } else if (type.startsWith(QLatin1String("video/")))
        kind = Kind::Video;
    else if (type.startsWith(QLatin1String("audio/")) && !type.contains(QLatin1String("mpegurl")) && !type.contains(QLatin1String("scpls")))
        kind = Kind::Audio;
    else if (type.startsWith(QLatin1String("font/")) || type == u"application/x-font-ttf" || type == u"application/x-font-otf"
             || type == u"application/vnd.ms-opentype")
        kind = Kind::Font;
    else if (type.startsWith(QLatin1String("application/vnd.openxmlformats-officedocument."))
             || type.startsWith(QLatin1String("application/vnd.oasis.opendocument."))
             || type.startsWith(QLatin1String("application/vnd.ms-word.")) || type.startsWith(QLatin1String("application/vnd.ms-excel.sheet."))
             || type.startsWith(QLatin1String("application/vnd.ms-powerpoint.")))
        kind = Kind::Office;
    kinds.insert(ext, kind);
    return kind;
}

QImage fit(const QImage &image, int box)
{
    if (image.isNull() || (image.width() <= box && image.height() <= box))
        return image;
    return image.scaled(box, box, Qt::KeepAspectRatio, Qt::SmoothTransformation);
}

// EXIF's orientations (1–8) applied to an image stored as the camera held it.
QImage oriented(const QImage &image, int orientation)
{
    QTransform t;
    switch (orientation) {
    case 2: t = QTransform(-1, 0, 0, 1, 0, 0); break;
    case 3: t.rotate(180); break;
    case 4: t = QTransform(1, 0, 0, -1, 0, 0); break;
    case 5: t = QTransform(0, 1, 1, 0, 0, 0); break;   // transpose
    case 6: t.rotate(90); break;
    case 7: t = QTransform(0, -1, -1, 0, 0, 0); break; // transverse
    case 8: t.rotate(270); break;
    default: return image;
    }
    return image.transformed(t);
}

// A JPEG's embedded EXIF thumbnail (IFD1), its orientation (IFD0) and the
// main image's size (SOF), from the segments at the file's start.
struct Exif {
    QByteArray thumb;
    int orientation = 1;
    QSize size;
};

Exif readExif(const QByteArray &head)
{
    Exif exif;
    const auto *p = reinterpret_cast<const uchar *>(head.constData());
    const qsizetype n = head.size();
    if (n < 4 || p[0] != 0xFF || p[1] != 0xD8)
        return exif;
    for (qsizetype at = 2; at + 4 <= n && p[at] == 0xFF;) {
        const uchar marker = p[at + 1];
        const qsizetype length = (qsizetype(p[at + 2]) << 8) | p[at + 3];
        if (marker == 0xDA || marker == 0xD9 || length < 2)
            break; // the image data
        // Start of frame (not DHT C4, JPG C8, DAC CC): the main image's size.
        if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC && at + 9 <= n) {
            exif.size = QSize((p[at + 7] << 8) | p[at + 8], (p[at + 5] << 8) | p[at + 6]);
            break;
        }
        if (marker == 0xE1 && exif.thumb.isEmpty() && at + 10 <= n && std::memcmp(p + at + 4, "Exif\0\0", 6) == 0) {
            const qsizetype tiff = at + 10, end = std::min(n, at + 2 + length);
            const bool little = tiff + 8 <= end && p[tiff] == 'I';
            auto u16 = [&](qsizetype o) -> quint32 {
                return o + 2 > end ? 0 : little ? p[o] | (p[o + 1] << 8) : (p[o] << 8) | p[o + 1];
            };
            auto u32 = [&](qsizetype o) -> quint32 {
                return o + 4 > end ? 0
                    : little ? quint32(p[o]) | (quint32(p[o + 1]) << 8) | (quint32(p[o + 2]) << 16) | (quint32(p[o + 3]) << 24)
                             : (quint32(p[o]) << 24) | (quint32(p[o + 1]) << 16) | (quint32(p[o + 2]) << 8) | quint32(p[o + 3]);
            };
            if (tiff + 8 <= end && u16(tiff + 2) == 42) {
                // IFD0, then IFD1 after it.
                quint32 ifd = u32(tiff + 4);
                quint32 offset = 0, size = 0;
                for (int which = 0; which < 2 && ifd && tiff + ifd + 2 <= end; ++which) {
                    const qsizetype base = tiff + ifd;
                    const quint32 count = std::min<quint32>(u16(base), 512);
                    for (quint32 i = 0; i < count; ++i) {
                        const qsizetype entry = base + 2 + 12 * i;
                        if (entry + 12 > end)
                            break;
                        const quint32 tag = u16(entry);
                        if (which == 0 && tag == 0x0112)
                            exif.orientation = int(u16(entry + 8));
                        else if (which == 1 && tag == 0x0201)
                            offset = u32(entry + 8);
                        else if (which == 1 && tag == 0x0202)
                            size = u32(entry + 8);
                    }
                    ifd = u32(base + 2 + 12 * count);
                }
                if (offset && size && tiff + qsizetype(offset) + qsizetype(size) <= end)
                    exif.thumb = head.mid(tiff + offset, size);
            }
        }
        at += 2 + length;
    }
    return exif;
}

// Whether Finder frames its thumbnail as a document's page (text, PDF,
// SVG, an office document), with rounder corners than a picture's.
bool isPage(const QString &path)
{
    const QString name = path.section(QLatin1Char('/'), -1);
    const Kind kind = kindOf(name);
    if (kind == Kind::Text || kind == Kind::Office)
        return true;
    const QString ext = QFileInfo(name).suffix().toLower();
    return ext == u"pdf" || ext == u"svg" || ext == u"svgz";
}

// A text file's first lines on a white, letter-shaped page, box pixels
// tall, monospaced as Finder sets them: drawn at least 256 tall and scaled
// down, so lines that are too small to read still sit as gray as Finder's.
QImage textPage(QFile &file, int box)
{
    const QByteArray head = file.read(3000);
    if (head.isEmpty() || head.contains('\0'))
        return {};
    const int height = std::max(box, 256), width = qRound(height * 8.5 / 11);
    QImage page(width, height, QImage::Format_ARGB32_Premultiplied);
    page.fill(Qt::white);
    QPainter painter(&page);
    painter.setRenderHint(QPainter::TextAntialiasing);
    QFont font = QFontDatabase::systemFont(QFontDatabase::FixedFont);
    font.setPixelSize(std::max(4, height / 58));
    painter.setFont(font);
    painter.setPen(QColor(0x1d, 0x1d, 0x1f));
    const qreal margin = width * 0.065, top = height * 0.055;
    painter.setClipRect(QRectF(margin, top, width - 2 * margin, height - 2 * top));
    painter.drawText(QRectF(margin, top, width - 2 * margin, height * 2), Qt::TextWordWrap | Qt::AlignLeft | Qt::AlignTop,
                     QString::fromUtf8(head).replace(QLatin1Char('\t'), QLatin1String("    ")));
    painter.end();
    return fit(page, box);
}

// A picture read at the size it is wanted: for a JPEG with an EXIF
// thumbnail big enough, that thumbnail; else Qt's reader at a scaled size
// (for JPEG, libjpeg-turbo's DCT scaling, an eighth of the work).
QImage picture(QFile &file, const QString &path, int box, QString *how, bool *smaller)
{
    const QByteArray head = file.peek(128 << 10);
    if (head.startsWith("\xFF\xD8\xFF")) {
        const Exif exif = readExif(head);
        if (!exif.thumb.isEmpty()) {
            const QImage thumb = QImage::fromData(exif.thumb, "JPEG");
            // Not a letterboxed one: the same shape as the photo.
            const bool shape = !exif.size.isValid() || exif.size.isEmpty()
                || std::abs(double(thumb.width()) / std::max(1, thumb.height()) - double(exif.size.width()) / exif.size.height()) < 0.03;
            if (!thumb.isNull() && std::max(thumb.width(), thumb.height()) >= box && shape) {
                if (how)
                    *how = QStringLiteral("exif");
                return fit(oriented(thumb, exif.orientation), box);
            }
        }
    }
    // Its kind by its extension first (SVG isn't told by its content alone
    // from a file handle), then by its content.
    QImageReader reader(&file, QFileInfo(path).suffix().toLower().toLatin1());
    reader.setAutoTransform(true);
    const QSize size = reader.size();
    const QByteArray format = reader.format();
    const bool vector = format == "svg" || format == "svgz" || format == "pdf";
    *smaller = !vector && size.isValid() && size.width() <= box && size.height() <= box;
    if (size.isValid() && !size.isEmpty() && (vector || !*smaller))
        reader.setScaledSize(size.scaled(box, box, Qt::KeepAspectRatio));
    const QImage image = reader.read();
    if (how)
        *how = QString::fromLatin1(format.isEmpty() ? QByteArray("?") : format);
    return fit(image, box);
}

// Three box blurs of r pixels (near enough a Gaussian) of an image's alpha;
// its color is black.
void blurAlpha(QImage &image, int r)
{
    const int w = image.width(), h = image.height();
    std::vector<int> a(size_t(w) * h), b(a.size());
    for (int y = 0; y < h; ++y) {
        const auto *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < w; ++x)
            a[size_t(y) * w + x] = qAlpha(line[x]);
    }
    // One pass along rows (step 1) or columns (step w), edges clear.
    auto pass = [&](const std::vector<int> &from, std::vector<int> &to, int count, int length, int step, int stride) {
        for (int i = 0; i < count; ++i) {
            const size_t base = size_t(i) * stride;
            int sum = 0;
            for (int j = 0; j <= r && j < length; ++j)
                sum += from[base + size_t(j) * step];
            for (int j = 0; j < length; ++j) {
                to[base + size_t(j) * step] = sum / (2 * r + 1);
                if (j + r + 1 < length)
                    sum += from[base + size_t(j + r + 1) * step];
                if (j - r >= 0)
                    sum -= from[base + size_t(j - r) * step];
            }
        }
    };
    for (int i = 0; i < 3; ++i) {
        pass(a, b, h, w, 1, w);
        pass(b, a, w, h, w, 1);
    }
    for (int y = 0; y < h; ++y) {
        auto *line = reinterpret_cast<QRgb *>(image.scanLine(y));
        for (int x = 0; x < w; ++x)
            line[x] = qRgba(0, 0, 0, a[size_t(y) * w + x]);
    }
}

// Finder's thumbnail as an icon, box pixels square: fitted into 9/10 of it,
// its corners rounded (6 pt of 64 for a picture, 8.5 for a page), a lighter
// hairline inside its edge and a soft shadow under it. Art with clear
// corners (an alpha channel) keeps its own shape, unframed.
QImage framed(const QImage &image, int box, bool page = false)
{
    QImage out(box, box, QImage::Format_ARGB32_Premultiplied);
    out.fill(Qt::transparent);
    if (image.isNull())
        return out;
    const int inner = box * 9 / 10;
    const QSize size = image.width() > inner || image.height() > inner ? image.size().scaled(inner, inner, Qt::KeepAspectRatio) : image.size();
    const QImage content = image.size() == size ? image : image.scaled(size, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    const QRectF rect((box - size.width()) / 2, (box - size.height()) / 2, size.width(), size.height());
    QPainter painter(&out);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);
    bool clear = false;
    if (content.hasAlphaChannel())
        for (const QPoint corner : {QPoint(0, 0), QPoint(content.width() - 1, 0), QPoint(0, content.height() - 1),
                                    QPoint(content.width() - 1, content.height() - 1)})
            clear = clear || qAlpha(content.pixel(corner)) < 250;
    if (clear) {
        painter.drawImage(rect.topLeft(), content);
        return out;
    }
    const qreal radius = std::min(box * (page ? 17 : 12) / 128.0, std::min(rect.width(), rect.height()) / 4);
    // The shadow: the shape a point lower, blurred, at a quarter black.
    QImage shadow(box, box, QImage::Format_ARGB32_Premultiplied);
    shadow.fill(Qt::transparent);
    {
        QPainter shade(&shadow);
        shade.setRenderHint(QPainter::Antialiasing);
        shade.setPen(Qt::NoPen);
        shade.setBrush(QColor(0, 0, 0, 72));
        shade.drawRoundedRect(rect.translated(0, box / 64.0), radius, radius);
    }
    blurAlpha(shadow, std::max(1, qRound(box / 48.0)));
    painter.drawImage(0, 0, shadow);
    QPainterPath shape;
    shape.addRoundedRect(rect, radius, radius);
    painter.setClipPath(shape);
    painter.drawImage(rect, content);
    painter.setClipping(false);
    painter.setPen(QPen(QColor(255, 255, 255, 120), std::max(1.0, box / 96.0)));
    painter.setBrush(Qt::NoBrush);
    painter.drawRoundedRect(rect.adjusted(0.5, 0.5, -0.5, -0.5), radius - 0.5, radius - 0.5);
    return out;
}

// One thumbnail of a file of the kind given, at most box pixels, made on
// the calling thread; how says which way, smaller that it isn't worth
// keeping in the cache (a picture already that small, a page of text).
QImage makeKind(Kind kind, QFile &file, const QString &path, int box, QString *how, bool *smaller)
{
    const QString suffix = QFileInfo(path).suffix().toLower();
    switch (kind) {
    case Kind::None:
        return {};
    case Kind::Picture:
        return picture(file, path, box, how, smaller);
    case Kind::Text:
        *how = QStringLiteral("text");
        *smaller = true; // cheap to draw again
        return textPage(file, box);
    case Kind::Video:
        *how = QStringLiteral("video");
        return Previews::video(file, box);
    case Kind::Font:
        *how = QStringLiteral("font");
        return Previews::font(file, box);
    case Kind::Audio:
        *how = QStringLiteral("audio");
        return Previews::audioCover(file, box);
    case Kind::Office:
        *how = QStringLiteral("office");
        return Previews::office(file, suffix, box, how);
    }
    return {};
}

// The freedesktop sizes, smallest first.
struct Bucket {
    int px;
    const char *dir;
};
constexpr Bucket buckets[] = {{128, "normal"}, {256, "large"}, {512, "x-large"}, {1024, "xx-large"}};

const QString &cacheRoot()
{
    static const QString root = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/thumbnails/");
    return root;
}

class Response;

struct Job {
    QString path;
    QString uri; // as the cache names it: file:// fully percent-encoded
    int box = 256;
    bool tile = false; // framed as Finder's icons (framed())
    quint64 burst = 0; // requests a moment apart: one view's rows
    bool looked = false; // in the cache
    std::atomic<bool> cancelled{false};
    std::mutex lock; // guards response
    Response *response = nullptr;
};

class Response : public QQuickImageResponse
{
public:
    explicit Response(const std::shared_ptr<Job> &job);
    ~Response() override
    {
        std::lock_guard locked(m_job->lock);
        m_job->response = nullptr;
    }
    QQuickTextureFactory *textureFactory() const override { return QQuickTextureFactory::textureFactoryForImage(image); }
    void cancel() override;

    QImage image;

private:
    std::shared_ptr<Job> m_job;
};

// Hands a job's image to QML once (a 1×1 clear one when none could be
// made, which FileIcon takes for "show the icon": an empty one would print
// a warning for every such file).
void finish(Job &job, QImage image)
{
    if (image.isNull()) {
        image = QImage(1, 1, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
    }
    std::lock_guard locked(job.lock);
    if (Response *response = std::exchange(job.response, nullptr)) {
        response->image = std::move(image);
        emit response->finished();
    }
}

class Pool
{
public:
    static Pool &instance()
    {
        static Pool pool;
        return pool;
    }

    void add(const std::shared_ptr<Job> &job)
    {
        {
            std::lock_guard locked(m_lock);
            if (m_threads.empty())
                for (int i = 0; i < 2; ++i)
                    m_threads.emplace_back([this] { run(); });
            const auto now = std::chrono::steady_clock::now();
            if (now - m_added > 100ms)
                ++m_burst;
            m_added = now;
            job->burst = m_burst;
            m_queue.push_back(job);
        }
        m_wake.notify_one();
    }
    void wake() { m_wake.notify_all(); }

    // Finishes what is running and lets the rest go.
    void stop()
    {
        std::vector<std::shared_ptr<Job>> left;
        {
            std::lock_guard locked(m_lock);
            m_stopping = true;
            left.assign(m_queue.begin(), m_queue.end());
            m_queue.clear();
        }
        m_wake.notify_all();
        for (std::thread &thread : m_threads)
            thread.join();
        m_threads.clear();
        for (const auto &job : left)
            finish(*job, {});
    }

private:
    ~Pool() { stop(); }

    // Whether making waits for the disk; called under m_lock.
    bool paused()
    {
        const auto now = std::chrono::steady_clock::now();
        if (now - m_checked >= 500ms) {
            m_checked = now;
            const double pressure = ioPressure();
            const bool was = m_paused;
            m_paused = m_paused ? pressure > resumeBelow : pressure > pauseAbove;
            if (trace && m_paused != was)
                std::fprintf(stderr, "files: thumbnails %s, I/O pressure %.1f%%\n", m_paused ? "paused" : "resumed", pressure);
        }
        return m_paused;
    }

    void run()
    {
        background();
        std::unique_lock locked(m_lock);
        while (!m_stopping) {
            // Drop the ones scrolled away.
            for (auto it = m_queue.begin(); it != m_queue.end();) {
                if ((*it)->cancelled) {
                    finish(**it, {});
                    it = m_queue.erase(it);
                } else {
                    ++it;
                }
            }
            // The newest view's rows first (after a scroll, the rows on
            // screen), in their order: one not yet looked for in the cache,
            // else (while the disk is calm) one to make.
            auto pick = [this](bool looked) {
                auto best = m_queue.end();
                for (auto it = m_queue.begin(); it != m_queue.end(); ++it)
                    if ((*it)->looked == looked && (best == m_queue.end() || (*it)->burst > (*best)->burst))
                        best = it;
                std::shared_ptr<Job> job;
                if (best != m_queue.end()) {
                    job = *best;
                    m_queue.erase(best);
                }
                return job;
            };
            std::shared_ptr<Job> job = pick(false);
            const bool calm = m_queue.empty() && !job ? true : !paused();
            if (!job && calm)
                job = pick(true);
            if (!job) {
                m_wake.wait_for(locked, m_queue.empty() ? 60s : 500ms);
                continue;
            }
            locked.unlock();
            const bool done = work(*job, calm);
            locked.lock();
            if (!done)
                m_queue.push_front(job); // first of its burst again
        }
    }

    // Looks for the job's thumbnail in the cache, and makes it unless the
    // disk is busy (false: put it back to wait).
    bool work(Job &job, bool calm)
    {
        if (job.cancelled) {
            finish(job, {});
            return true;
        }
        struct stat st;
        if (::stat(QFile::encodeName(job.path).constData(), &st) != 0 || !S_ISREG(st.st_mode) || st.st_size > largest) {
            finish(job, {});
            return true;
        }
        const qint64 mtime = st.st_mtim.tv_sec;
        const QString key = job.path + QLatin1Char('\n') + QString::number(mtime);
        const Bucket *bucket = nullptr;
        for (const Bucket &b : buckets)
            if (!bucket && b.px >= job.box)
                bucket = &b;
        const QString name = QString::fromLatin1(QCryptographicHash::hash(job.uri.toUtf8(), QCryptographicHash::Md5).toHex()) + QStringLiteral(".png");
        if (!job.looked) {
            job.looked = true;
            {
                QMutexLocker failures(&m_failedLock);
                if (m_failed.contains(key)) {
                    finish(job, {});
                    return true;
                }
            }
            // This size or a bigger one, made by us or any other app.
            for (const Bucket *b = bucket; b && b != std::end(buckets); ++b) {
                QImage cached(cacheRoot() + QLatin1String(b->dir) + QLatin1Char('/') + name, "PNG");
                if (!cached.isNull() && cached.text(QStringLiteral("Thumb::MTime")).toLongLong() == mtime
                    && cached.text(QStringLiteral("Thumb::URI")) == job.uri) {
                    finish(job, deliver(job, fit(cached, job.box)));
                    return true;
                }
            }
            if (!calm)
                return false;
        }
        if (job.cancelled) {
            finish(job, {});
            return true;
        }
        QElapsedTimer clock;
        clock.start();
        const int px = bucket ? bucket->px : job.box;
        QString how;
        bool smaller = false;
        QImage image;
        QFile file;
        if (openQuietly(file, job.path))
            image = makeKind(kindOf(job.path.section(QLatin1Char('/'), -1)), file, job.path, px, &how, &smaller);
        if (trace)
            std::fprintf(stderr, "files: thumbnail %-5s %6.1f ms %s\n", qPrintable(how), clock.nsecsElapsed() / 1e6, qPrintable(job.path));
        if (image.isNull()) {
            QMutexLocker failures(&m_failedLock);
            m_failed.insert(key);
            finish(job, {});
            return true;
        }
        finish(job, deliver(job, fit(image, job.box)));
        // Kept for every app, as the spec says: not for pictures already
        // that small, nor past the biggest size.
        if (bucket && !smaller)
            store(image, cacheRoot() + QLatin1String(bucket->dir), name, job.uri, mtime, st.st_size);
        return true;
    }

    static QImage deliver(const Job &job, const QImage &image) { return job.tile ? framed(image, job.box, isPage(job.path)) : image; }

    static void store(QImage image, const QString &dir, const QString &name, const QString &uri, qint64 mtime, qint64 size)
    {
        if (!QDir().mkpath(dir))
            return;
        ::chmod(QFile::encodeName(dir).constData(), 0700);
        image.setText(QStringLiteral("Thumb::URI"), uri);
        image.setText(QStringLiteral("Thumb::MTime"), QString::number(mtime));
        image.setText(QStringLiteral("Thumb::Size"), QString::number(size));
        image.setText(QStringLiteral("Software"), QStringLiteral("Ambrosia Files"));
        // Written whole, then renamed into place, but not synced: a lost
        // thumbnail is only made again, and on a spinning disk each sync
        // held a thread for tens of milliseconds.
        QTemporaryFile file(dir + QStringLiteral("/.ambrosia-XXXXXX.png")); // 0600, as the spec asks
        file.setAutoRemove(false);
        if (!file.open())
            return;
        const bool saved = image.save(&file, "PNG", 50);
        file.close();
        if (!saved || ::rename(QFile::encodeName(file.fileName()).constData(), QFile::encodeName(dir + QLatin1Char('/') + name).constData()) != 0)
            QFile::remove(file.fileName());
    }

    std::mutex m_lock;
    std::condition_variable m_wake;
    std::deque<std::shared_ptr<Job>> m_queue;
    std::vector<std::thread> m_threads;
    bool m_stopping = false;
    bool m_paused = false;
    quint64 m_burst = 0;
    std::chrono::steady_clock::time_point m_added;
    std::chrono::steady_clock::time_point m_checked;
    QMutex m_failedLock;
    QSet<QString> m_failed; // path and mtime of files none could be made for
};

Response::Response(const std::shared_ptr<Job> &job)
    : m_job(job)
{
    m_job->response = this;
}

void Response::cancel()
{
    m_job->cancelled = true;
    Pool::instance().wake();
}

}

Thumbnailer::~Thumbnailer()
{
    Pool::instance().stop();
}

QQuickImageResponse *Thumbnailer::requestImageResponse(const QString &id, const QSize &requestedSize)
{
    // MTIME/PATH, then what it is shown as: audio (the model's hint for the
    // icon meanwhile), tile (framed, as Finder's icons).
    auto job = std::make_shared<Job>();
    const QStringList parts = id.split(QLatin1Char('/'));
    job->path = QUrl::fromPercentEncoding(parts.value(1).toUtf8());
    job->tile = parts.mid(2).contains(QLatin1String("tile"));
    job->uri = QUrl::fromLocalFile(job->path).toString(QUrl::FullyEncoded);
    if (requestedSize.isValid() && !requestedSize.isEmpty())
        job->box = std::max(requestedSize.width(), requestedSize.height());
    auto *response = new Response(job);
    Pool::instance().add(job);
    return response;
}

QString Thumbnailer::source(const QUrl &url, const QString &name, bool isDir, qint64 mtime)
{
    const Kind kind = isDir || mtime <= 0 ? Kind::None : kindOf(name);
    if (kind == Kind::None)
        return {};
    QString path;
    if (url.isLocalFile())
        path = url.toLocalFile();
    // The home Trash's items are files in ~/.local/share/Trash/files.
    else if (url.scheme() == QLatin1String("trash") && url.path().startsWith(QLatin1String("/0-")))
        path = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QLatin1String("/Trash/files/") + url.path().mid(3);
    else
        return {};
    return QStringLiteral("image://thumb/") + QString::number(mtime) + QLatin1Char('/') + QString::fromLatin1(QUrl::toPercentEncoding(path))
        + (kind == Kind::Audio ? QStringLiteral("/audio") : QString());
}

QImage Thumbnailer::make(const QString &path, int box, QString *how)
{
    QFile file;
    if (!openQuietly(file, path))
        return {};
    QString made;
    bool smaller = false;
    const QImage image = makeKind(kindOf(path.section(QLatin1Char('/'), -1)), file, path, box, &made, &smaller);
    if (how)
        *how = made;
    return image;
}

QImage Thumbnailer::frame(const QImage &image, int box)
{
    return framed(image, box);
}
