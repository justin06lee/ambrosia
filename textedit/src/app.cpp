#include "app.h"

#include <optional>
#include "shadow.h"

#include <KWindowShadow>
#include <KWindowSystem>

#include <QDir>
#include <QFile>
#include <QFileDialog>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QMimeDatabase>
#include <QPalette>
#include <QQmlEngine>
#include <QSaveFile>
#include <QStandardPaths>
#include <QStringDecoder>
#include <QStyleHints>
#include <QTimer>

App *App::s_instance = nullptr;

App::App(const Options &options)
    : m_options(options)
{
    s_instance = this;
    QJSEngine::setObjectOwnership(this, QJSEngine::CppOwnership);
    connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged, this, &App::appearanceChanged);
    connect(qGuiApp, &QGuiApplication::paletteChanged, this, &App::appearanceChanged);
}

App *App::create(QQmlEngine *, QJSEngine *)
{
    return s_instance;
}

bool App::dark() const
{
    if (!m_options.appearance.isEmpty())
        return m_options.appearance == QLatin1String("dark");
    return QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
}

QColor App::accent() const
{
    if (!m_options.appearance.isEmpty())
        return {};
    return QGuiApplication::palette().color(QPalette::Active, QPalette::Highlight);
}

QStringList App::families() const
{
    if (m_families.isEmpty()) {
        const QStringList all = QFontDatabase::families();
        // A family's weights that fontconfig also names as families of
        // their own ("Inter Black" beside "Inter") are that family's
        // styles, not more families.
        static const QStringList weights{QStringLiteral(" Thin"), QStringLiteral(" ExtraLight"), QStringLiteral(" Light"), QStringLiteral(" Medium"),
                                         QStringLiteral(" SemiBold"), QStringLiteral(" ExtraBold"), QStringLiteral(" Black"), QStringLiteral(" Heavy"),
                                         QStringLiteral(" DemiBold"), QStringLiteral(" Bold"), QStringLiteral(" Regular"), QStringLiteral(" Italic")};
        const auto isWeight = [&all](const QString &family) {
            for (const QString &weight : weights) {
                if (family.endsWith(weight) && all.contains(family.chopped(weight.size())))
                    return true;
            }
            return false;
        };
        for (const QString &family : all) {
            // Not the foundry-marked doubles ("Helvetica [Adobe]"), nor
            // the fonts a system hides behind a dot.
            if (!family.contains(QLatin1Char('[')) && !family.startsWith(QLatin1Char('.')) && !QFontDatabase::isPrivateFamily(family) && !isWeight(family))
                m_families << family;
        }
    }
    return m_families;
}

void App::decorate(QQuickWindow *window, int radius)
{
    if (!window || QGuiApplication::platformName() == QLatin1String("offscreen"))
        return;
    auto *shadow = makeShadow(window, radius, window->devicePixelRatio());
    if (!shadow->create())
        qWarning("TextEdit: KWin took no shadow for the window");
}

void App::shown(QQuickWindow *window)
{
    if (m_options.grab.isEmpty() || m_grabbed)
        return;
    m_grabbed = true;
    QTimer::singleShot(700, window, [this, window] {
        window->grabWindow().save(m_options.grab);
        QGuiApplication::quit();
    });
}

void App::activate(QQuickWindow *window)
{
    if (!window)
        return;
    if (window->visibility() == QWindow::Minimized)
        window->showNormal();
    KWindowSystem::activateWindow(window);
}

QString App::name(const QUrl &file) const
{
    return file.fileName();
}

QString App::iconName(const QUrl &file) const
{
    return QMimeDatabase().mimeTypeForFile(file.toLocalFile()).iconName();
}

// TextEdit's Settings name an encoding for plain text ("utf-8", "utf-16",
// "latin1"); anything else is Automatic: the file's own mark, else UTF-8.
static std::optional<QStringConverter::Encoding> named(const QString &encoding)
{
    if (encoding == QLatin1String("utf-8"))
        return QStringConverter::Utf8;
    if (encoding == QLatin1String("utf-16"))
        return QStringConverter::Utf16;
    if (encoding == QLatin1String("latin1"))
        return QStringConverter::Latin1;
    return std::nullopt;
}

QVariantMap App::read(const QUrl &file, const QString &encoding) const
{
    QFile source(file.toLocalFile());
    if (!source.open(QIODevice::ReadOnly))
        return {{QStringLiteral("ok"), false}, {QStringLiteral("error"), source.errorString()}};
    const QByteArray data = source.readAll();
    QVariantMap out{{QStringLiteral("ok"), true}};
    if (data.startsWith("{\\rtf")) {
        out[QStringLiteral("rtf")] = true;
        out[QStringLiteral("text")] = QString::fromLatin1(data);
        return out;
    }
    out[QStringLiteral("rtf")] = false;
    const auto marked = QStringConverter::encodingForData(data);
    QStringDecoder decoder(named(encoding).value_or(marked.value_or(QStringConverter::Utf8)));
    QString text = decoder.decode(data);
    if (decoder.hasError())
        text = QString::fromLatin1(data);
    // One kind of line end inside; a file's own is not kept.
    text.replace(QLatin1String("\r\n"), QLatin1String("\n"));
    text.replace(QLatin1Char('\r'), QLatin1Char('\n'));
    out[QStringLiteral("text")] = text;
    return out;
}

QString App::write(const QUrl &file, const QString &text, bool bytes, const QString &encoding) const
{
    QSaveFile target(file.toLocalFile());
    if (!target.open(QIODevice::WriteOnly))
        return target.errorString();
    if (bytes) {
        target.write(text.toLatin1());
    } else {
        // UTF-16 carries its mark, so it is read back as what it is.
        const auto to = named(encoding).value_or(QStringConverter::Utf8);
        QStringEncoder encoder(to, to == QStringConverter::Utf16 ? QStringConverter::Flag::WriteBom : QStringConverter::Flag::Default);
        target.write(encoder.encode(text));
    }
    if (!target.commit())
        return target.errorString();
    return {};
}

QString App::decode(int codepage, const QString &bytes) const
{
    QByteArrayList names{QByteArray("windows-") + QByteArray::number(codepage), QByteArray("cp") + QByteArray::number(codepage),
                         QByteArray("ibm-") + QByteArray::number(codepage)};
    switch (codepage) {
    case 932: names.prepend("Shift_JIS"); break;
    case 936: names.prepend("GBK"); break;
    case 949: names.prepend("EUC-KR"); break;
    case 950: names.prepend("Big5"); break;
    case 1361: names.prepend("Johab"); break;
    }
    for (const QByteArray &name : std::as_const(names)) {
        QStringDecoder decoder(name.constData());
        if (decoder.isValid())
            return decoder.decode(bytes.toLatin1());
    }
    return {};
}

QString App::family(const QString &asked) const
{
    const QStringList all = families();
    if (all.contains(asked))
        return asked;
    const auto bare = [](QString name) { return name.remove(QLatin1Char(' ')).remove(QLatin1Char('-')).toLower(); };
    const QString want = bare(asked);
    for (const QString &family : all) {
        if (bare(family) == want)
            return family;
    }
    return asked;
}

QStringList App::styles(const QString &family) const
{
    QStringList styles = QFontDatabase::styles(family);
    // A family that is only another's name here (Helvetica) has the four.
    if (styles.isEmpty())
        styles = {QStringLiteral("Regular"), QStringLiteral("Italic"), QStringLiteral("Bold"), QStringLiteral("Bold Italic")};
    return styles;
}

QVariantMap App::style(const QString &family, const QString &style) const
{
    int weight = QFontDatabase::weight(family, style);
    bool italic = QFontDatabase::italic(family, style);
    if (weight <= 0) {
        weight = style.contains(QLatin1String("Bold")) ? QFont::Bold : QFont::Normal;
        italic = style.contains(QLatin1String("Italic")) || style.contains(QLatin1String("Oblique"));
    }
    return {{QStringLiteral("weight"), weight}, {QStringLiteral("italic"), italic}};
}

void App::chooseFiles()
{
    if (m_choosing)
        return;
    m_choosing = true;
    auto *dialog = new QFileDialog(nullptr, QStringLiteral("Open"));
    dialog->setAttribute(Qt::WA_DeleteOnClose);
    dialog->setFileMode(QFileDialog::ExistingFiles);
    dialog->setAcceptMode(QFileDialog::AcceptOpen);
    dialog->setMimeTypeFilters({QStringLiteral("text/plain"), QStringLiteral("application/rtf"), QStringLiteral("application/octet-stream")});
    const QStringList documents = QStandardPaths::standardLocations(QStandardPaths::DocumentsLocation);
    if (!documents.isEmpty())
        dialog->setDirectory(documents.first());
    connect(dialog, &QFileDialog::finished, this, [this, dialog](int result) {
        m_choosing = false;
        QStringList chosen;
        if (result == QDialog::Accepted) {
            const QList<QUrl> urls = dialog->selectedUrls();
            for (const QUrl &url : urls)
                chosen << url.toString();
        }
        if (!chosen.isEmpty())
            Q_EMIT openRequested(chosen);
    });
    dialog->open();
}

QStringList App::urls(const QStringList &arguments)
{
    QStringList urls;
    for (const QString &argument : arguments) {
        const QUrl given(argument);
        if (given.isValid() && !given.scheme().isEmpty() && given.scheme().size() > 1)
            urls << given.toString();
        else
            urls << QUrl::fromLocalFile(QFileInfo(argument).absoluteFilePath()).toString();
    }
    return urls;
}

void App::Open(const QStringList &files, const QString &token)
{
    if (!token.isEmpty())
        KWindowSystem::setCurrentXdgActivationToken(token);
    if (files.isEmpty())
        Q_EMIT raiseRequested();
    else
        Q_EMIT openRequested(files);
}

Icons::Icons()
    : QQuickImageProvider(QQuickImageProvider::Pixmap)
{
}

QPixmap Icons::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QSize want = requestedSize.isValid() ? requestedSize : QSize(32, 32);
    QIcon icon = QIcon::fromTheme(id);
    if (icon.isNull())
        icon = QIcon::fromTheme(QStringLiteral("text-x-generic"));
    const QPixmap pixmap = icon.pixmap(want);
    if (size)
        *size = pixmap.size();
    return pixmap;
}
