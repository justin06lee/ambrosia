#include "library.h"

#include <QChar>
#include <QCollator>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QFontDatabase>
#include <QLocale>
#include <QSet>
#include <QStandardPaths>
#include <QTimer>

#include <algorithm>

#include <fontconfig/fontconfig.h>
#include <fontconfig/fcfreetype.h>

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_SFNT_NAMES_H
#include FT_TRUETYPE_IDS_H
#include FT_TRUETYPE_TABLES_H

namespace
{
FT_Library freetype()
{
    static FT_Library library = nullptr;
    if (!library)
        FT_Init_FreeType(&library);
    return library;
}

// What a font can write, told by one character of each script: the keys
// are named and shown by fontbook.mjs.
const struct {
    const char *key;
    FcChar32 probe;
} kScripts[] = {
    {"latin", 0x0061},     {"cyrillic", 0x0436}, {"greek", 0x03B1},    {"armenian", 0x0561}, {"georgian", 0x10D0},   {"hebrew", 0x05D0},
    {"arabic", 0x0639},    {"devanagari", 0x0915}, {"bengali", 0x0995}, {"gurmukhi", 0x0A15}, {"gujarati", 0x0A95},   {"oriya", 0x0B15},
    {"tamil", 0x0B95},     {"telugu", 0x0C15},   {"kannada", 0x0C95},  {"malayalam", 0x0D15}, {"sinhala", 0x0D9A},   {"thai", 0x0E01},
    {"lao", 0x0E81},       {"tibetan", 0x0F40},  {"myanmar", 0x1000},  {"khmer", 0x1780},    {"ethiopic", 0x12A0},   {"cherokee", 0x13A0},
    {"mongolian", 0x1820}, {"hangul", 0xAC00},   {"hiragana", 0x3042}, {"katakana", 0x30A2}, {"han", 0x6F22},        {"braille", 0x283F},
    {"emoji", 0x1F600},    {"math", 0x2211},
};

QString text(const FcChar8 *chars)
{
    return QString::fromUtf8(reinterpret_cast<const char *>(chars));
}

// The value of a pattern's name in English where it has several (a family
// may carry its name in each language it is sold in).
QString named(FcPattern *pattern, const char *object, const char *langObject)
{
    FcChar8 *value = nullptr;
    QString first;
    for (int i = 0; FcPatternGetString(pattern, object, i, &value) == FcResultMatch; ++i) {
        if (i == 0)
            first = text(value);
        FcChar8 *lang = nullptr;
        if (FcPatternGetString(pattern, langObject, i, &lang) == FcResultMatch && qstrcmp(reinterpret_cast<const char *>(lang), "en") == 0)
            return text(value);
    }
    return first;
}

// The kind of file, in a Mac's words.
QString formatName(FcPattern *pattern)
{
    FcChar8 *format = nullptr;
    if (FcPatternGetString(pattern, FC_FONTFORMAT, 0, &format) != FcResultMatch)
        return {};
    const QString kind = text(format);
    if (kind == QLatin1String("CFF"))
        return QStringLiteral("OpenType PostScript");
    if (kind == QLatin1String("TrueType")) {
        // With OpenType's layout tables it is an OpenType font.
        FcChar8 *capability = nullptr;
        if (FcPatternGetString(pattern, FC_CAPABILITY, 0, &capability) == FcResultMatch && text(capability).contains(QLatin1String("otlayout")))
            return QStringLiteral("OpenType TrueType");
        return QStringLiteral("TrueType");
    }
    if (kind == QLatin1String("Type 1"))
        return QStringLiteral("PostScript Type 1");
    return kind;
}

struct Face {
    QString family;
    QString style;
    QString file;
    QString postscript;
    QString full;
    QString format;
    int index = 0;
    int weight = 80;
    int width = 100;
    int slant = 0;
    bool variable = false;
    bool mono = false;
    bool color = false;
    QStringList scripts;
    QString first;
    QStringList langs;
};

Face faceOf(FcPattern *pattern)
{
    Face face;
    face.family = named(pattern, FC_FAMILY, FC_FAMILYLANG);
    face.style = named(pattern, FC_STYLE, FC_STYLELANG);
    FcChar8 *value = nullptr;
    if (FcPatternGetString(pattern, FC_FILE, 0, &value) == FcResultMatch)
        face.file = QFile::decodeName(reinterpret_cast<const char *>(value));
    if (FcPatternGetString(pattern, FC_POSTSCRIPT_NAME, 0, &value) == FcResultMatch)
        face.postscript = text(value);
    if (FcPatternGetString(pattern, FC_FULLNAME, 0, &value) == FcResultMatch)
        face.full = text(value);
    face.format = formatName(pattern);
    FcPatternGetInteger(pattern, FC_INDEX, 0, &face.index);
    // A variable font's weight is a range, which reads as no integer: the
    // defaults stand then.
    FcPatternGetInteger(pattern, FC_WEIGHT, 0, &face.weight);
    FcPatternGetInteger(pattern, FC_WIDTH, 0, &face.width);
    FcPatternGetInteger(pattern, FC_SLANT, 0, &face.slant);
    FcBool flag = FcFalse;
    if (FcPatternGetBool(pattern, FC_VARIABLE, 0, &flag) == FcResultMatch)
        face.variable = flag;
    if (FcPatternGetBool(pattern, FC_COLOR, 0, &flag) == FcResultMatch)
        face.color = flag;
    int spacing = FC_PROPORTIONAL;
    if (FcPatternGetInteger(pattern, FC_SPACING, 0, &spacing) == FcResultMatch)
        face.mono = spacing >= FC_MONO;

    FcCharSet *chars = nullptr;
    if (FcPatternGetCharSet(pattern, FC_CHARSET, 0, &chars) == FcResultMatch && chars) {
        for (const auto &script : kScripts) {
            if (FcCharSetHasChar(chars, script.probe))
                face.scripts << QLatin1String(script.key);
        }
        // The first two letters or symbols it draws past the Latin most
        // fonts carry: what stands for a font of symbols alone, or of a
        // script not told above. One with nothing there has its first
        // two letters or numbers.
        FcChar32 map[FC_CHARSET_MAP_SIZE];
        FcChar32 next = 0;
        QString plain, far;
        int plainFound = 0, farFound = 0;
        for (FcChar32 base = FcCharSetFirstPage(chars, map, &next); base != FC_CHARSET_DONE && farFound < 2; base = FcCharSetNextPage(chars, map, &next)) {
            for (int word = 0; word < FC_CHARSET_MAP_SIZE && farFound < 2; ++word) {
                for (int bit = 0; bit < 32 && farFound < 2; ++bit) {
                    if (!(map[word] & (1u << bit)))
                        continue;
                    const char32_t code = base + word * 32 + bit;
                    if (code < 0x250) {
                        if (plainFound < 2 && QChar::isLetterOrNumber(code)) {
                            plain += QString::fromUcs4(&code, 1);
                            ++plainFound;
                        }
                        continue;
                    }
                    // Not marks that join a letter, spaces, punctuation, the
                    // dotted ring marks are shown on, or private characters.
                    const QChar::Category category = QChar::category(code);
                    const bool letter = category >= QChar::Letter_Uppercase && category <= QChar::Letter_Other;
                    const bool symbol = category == QChar::Symbol_Math || category == QChar::Symbol_Other || category == QChar::Number_Other;
                    if ((!letter && !symbol) || code == 0x25CC || (code >= 0x2000 && code < 0x2100))
                        continue;
                    far += QString::fromUcs4(&code, 1);
                    ++farFound;
                }
            }
        }
        face.first = far.isEmpty() ? plain : far;
    }
    FcLangSet *langs = nullptr;
    if (FcPatternGetLangSet(pattern, FC_LANG, 0, &langs) == FcResultMatch && langs) {
        FcStrSet *set = FcLangSetGetLangs(langs);
        FcStrList *list = FcStrListCreate(set);
        while (FcChar8 *lang = FcStrListNext(list))
            face.langs << text(lang);
        FcStrListDone(list);
        FcStrSetDestroy(set);
    }
    return face;
}

// A language by fontconfig's code, in English: "en" English, "zh-cn"
// Chinese, Simplified. Empty for a code Qt has no name for.
QString languageName(const QString &code)
{
    if (code == QLatin1String("zh-cn") || code == QLatin1String("zh-sg"))
        return QStringLiteral("Chinese, Simplified");
    if (code == QLatin1String("zh-tw") || code == QLatin1String("zh-hk") || code == QLatin1String("zh-mo"))
        return QStringLiteral("Chinese, Traditional");
    const QLocale locale(QString(code).replace(QLatin1Char('-'), QLatin1Char('_')));
    if (locale.language() == QLocale::C || locale.language() == QLocale::AnyLanguage)
        return {};
    // Qt answers English for a code it doesn't know.
    if (locale.language() == QLocale::English && !code.startsWith(QLatin1String("en")))
        return {};
    return QLocale::languageToString(locale.language());
}

// One of a font file's own names (its name table), in English where it
// says it in several languages.
QString sfntName(FT_Face face, int id)
{
    QString mac;
    const FT_UInt count = FT_Get_Sfnt_Name_Count(face);
    for (FT_UInt i = 0; i < count; ++i) {
        FT_SfntName name;
        if (FT_Get_Sfnt_Name(face, i, &name) != 0 || name.name_id != id || name.string_len == 0)
            continue;
        if (name.platform_id == TT_PLATFORM_MICROSOFT || name.platform_id == TT_PLATFORM_APPLE_UNICODE) {
            // UTF-16, big end first.
            QString value;
            value.reserve(name.string_len / 2);
            for (FT_UInt k = 0; k + 1 < name.string_len; k += 2)
                value += QChar(char16_t((name.string[k] << 8) | name.string[k + 1]));
            if (name.platform_id == TT_PLATFORM_APPLE_UNICODE || name.language_id == TT_MS_LANGID_ENGLISH_UNITED_STATES)
                return value.trimmed();
            if (mac.isEmpty())
                mac = value.trimmed();
        } else if (name.platform_id == TT_PLATFORM_MACINTOSH && name.language_id == TT_MAC_LANGID_ENGLISH && mac.isEmpty()) {
            mac = QString::fromLatin1(reinterpret_cast<const char *>(name.string), name.string_len).trimmed();
        }
    }
    return mac;
}

// What a font allows of being put inside a document (its OS/2 table), in
// the words the OpenType specification gives each.
QString embedding(FT_Face face)
{
    const auto *os2 = static_cast<TT_OS2 *>(FT_Get_Sfnt_Table(face, FT_SFNT_OS2));
    if (!os2)
        return {};
    const int type = os2->fsType & 0x000F;
    if (type & 0x2)
        return QStringLiteral("Restricted License embedding. This font must not be modified, embedded or exchanged in any manner without first obtaining permission of the legal owner.");
    if (type & 0x4)
        return QStringLiteral("Preview and print embedding. This font may be embedded in documents and temporarily loaded on the remote system. Documents containing this font must be opened read-only.");
    if (type & 0x8)
        return QStringLiteral("Editable embedding. This font may be embedded in documents and temporarily loaded on the remote system. Documents containing this font may be edited.");
    return QStringLiteral("Installable embedding. This font may be embedded in documents and permanently installed on the remote system.");
}

// The same bytes in both files.
bool sameFile(const QString &a, const QString &b)
{
    QFile first(a), second(b);
    if (!first.open(QIODevice::ReadOnly) || !second.open(QIODevice::ReadOnly) || first.size() != second.size())
        return false;
    QCryptographicHash one(QCryptographicHash::Sha1), two(QCryptographicHash::Sha1);
    return one.addData(&first) && two.addData(&second) && one.result() == two.result();
}

// How far a style is from the plain one: regular weight, upright, of
// normal width.
int plainness(const Face &face)
{
    return (face.width != 100 ? 2000 : 0) + (face.slant != 0 ? 1000 : 0) + qAbs(face.weight - 80);
}

QVariantMap styleMap(const Face &face, bool user)
{
    return {
        {QStringLiteral("name"), face.style.isEmpty() ? QStringLiteral("Regular") : face.style},
        {QStringLiteral("file"), face.file},
        {QStringLiteral("index"), face.index},
        {QStringLiteral("postscript"), face.postscript},
        {QStringLiteral("full"), face.full},
        {QStringLiteral("weight"), face.weight},
        {QStringLiteral("width"), face.width},
        {QStringLiteral("slant"), face.slant},
        {QStringLiteral("format"), face.format},
        {QStringLiteral("user"), user},
    };
}
}

Library::Library(QObject *parent)
    : QObject(parent)
    , m_watcher(new QFileSystemWatcher(this))
    , m_settle(new QTimer(this))
{
    // A font put into the user's folder by other hands (or taken out)
    // shows without being asked for: a moment after the folder settles.
    m_settle->setSingleShot(true);
    m_settle->setInterval(600);
    connect(m_settle, &QTimer::timeout, this, &Library::refresh);
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, m_settle, qOverload<>(&QTimer::start));
    for (const QString &folder : userFolders()) {
        if (QFileInfo(folder).isDir())
            m_watcher->addPath(folder);
    }
    refresh();
}

QString Library::userFolder() const
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/fonts");
}

QStringList Library::userFolders() const
{
    return {userFolder(), QDir::homePath() + QStringLiteral("/.fonts")};
}

bool Library::isUser(const QString &file) const
{
    for (const QString &folder : userFolders()) {
        if (file.startsWith(folder + QLatin1Char('/')))
            return true;
    }
    return false;
}

QVariantList Library::languages() const
{
    QVariantList languages;
    QSet<QString> seen;
    for (const QString &tag : QLocale::system().uiLanguages()) {
        const QString code = tag.section(QLatin1Char('-'), 0, 0).toLower();
        if (code.isEmpty() || code == QLatin1String("c") || seen.contains(code))
            continue;
        seen.insert(code);
        const QString name = languageName(code);
        if (!name.isEmpty())
            languages << QVariantMap{{QStringLiteral("code"), code}, {QStringLiteral("name"), name}};
    }
    if (languages.isEmpty())
        languages << QVariantMap{{QStringLiteral("code"), QStringLiteral("en")}, {QStringLiteral("name"), QStringLiteral("English")}};
    return languages;
}

void Library::refresh()
{
    // A configuration of our own, read anew: the one Qt draws by is left
    // as it is, and a font added a moment ago is in this one.
    FcConfig *config = FcInitLoadConfigAndFonts();
    FcPattern *all = FcPatternCreate();
    FcObjectSet *wanted = FcObjectSetBuild(FC_FAMILY, FC_FAMILYLANG, FC_STYLE, FC_STYLELANG, FC_FILE, FC_INDEX, FC_FONTFORMAT, FC_POSTSCRIPT_NAME,
                                           FC_FULLNAME, FC_WEIGHT, FC_SLANT, FC_WIDTH, FC_SPACING, FC_LANG, FC_CHARSET, FC_VARIABLE, FC_COLOR,
                                           FC_CAPABILITY, FC_SCALABLE, nullptr);
    FcFontSet *set = FcFontList(config, all, wanted);

    QList<Face> faces;
    QSet<QString> instanced; // files that name their own styles
    for (int i = 0; set && i < set->nfont; ++i) {
        // Fonts of fixed pictures (X's old bitmap fonts) draw at their own
        // few sizes only: left out.
        FcBool scalable = FcTrue;
        if (FcPatternGetBool(set->fonts[i], FC_SCALABLE, 0, &scalable) == FcResultMatch && !scalable)
            continue;
        Face face = faceOf(set->fonts[i]);
        if (face.family.isEmpty() || face.file.isEmpty())
            continue;
        if (!face.variable)
            instanced.insert(face.file + QLatin1Char('#') + QString::number(face.index & 0xFFFF));
        faces << face;
    }
    if (set)
        FcFontSetDestroy(set);
    FcObjectSetDestroy(wanted);
    FcPatternDestroy(all);
    FcConfigDestroy(config);

    // A variable font is listed once as itself and once for each style it
    // names: the named ones are its styles, itself only where it names none.
    QHash<QString, QList<Face>> byFamily;
    for (const Face &face : std::as_const(faces)) {
        if (face.variable && instanced.contains(face.file + QLatin1Char('#') + QString::number(face.index & 0xFFFF)))
            continue;
        byFamily[face.family] << face;
    }

    QStringList names = byFamily.keys();
    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    collator.setNumericMode(true);
    std::sort(names.begin(), names.end(), [&collator](const QString &a, const QString &b) { return collator.compare(a, b) < 0; });

    QVariantList families;
    for (const QString &name : std::as_const(names)) {
        QList<Face> styles = byFamily.value(name);
        // The upright widths first, light to bold, then the narrow and
        // the wide ones; a style under the same name twice (the system's
        // and the user's copy) is kept once, the user's.
        std::stable_sort(styles.begin(), styles.end(), [this](const Face &a, const Face &b) {
            const int aw = a.width == 100 ? 0 : 1, bw = b.width == 100 ? 0 : 1;
            if (aw != bw)
                return aw < bw;
            if (a.width != b.width)
                return a.width < b.width;
            if (a.weight != b.weight)
                return a.weight < b.weight;
            if (a.slant != b.slant)
                return a.slant < b.slant;
            return isUser(a.file) && !isUser(b.file);
        });
        QVariantList list;
        QSet<QString> seen;
        bool user = false;
        // The plainest style speaks for the family.
        const Face *plain = nullptr;
        for (const Face &face : std::as_const(styles)) {
            const QString style = face.style.isEmpty() ? QStringLiteral("Regular") : face.style;
            if (seen.contains(style))
                continue;
            seen.insert(style);
            const bool mine = isUser(face.file);
            user = user || mine;
            list << styleMap(face, mine);
            if (!plain || plainness(face) < plainness(*plain))
                plain = &face;
        }
        if (!plain)
            continue;
        families << QVariantMap{
            {QStringLiteral("family"), name},
            {QStringLiteral("styles"), list},
            {QStringLiteral("user"), user},
            {QStringLiteral("mono"), plain->mono},
            {QStringLiteral("color"), plain->color},
            {QStringLiteral("format"), plain->format},
            {QStringLiteral("scripts"), plain->scripts},
            {QStringLiteral("first"), plain->first},
            {QStringLiteral("langs"), plain->langs},
        };
    }
    m_families = families;
    Q_EMIT changed();
}

QVariantMap Library::details(const QString &family) const
{
    QVariantList styles;
    QStringList langs;
    for (const QVariant &entry : m_families) {
        const QVariantMap map = entry.toMap();
        if (map.value(QStringLiteral("family")).toString() != family)
            continue;
        langs = map.value(QStringLiteral("langs")).toStringList();
        const QVariantList list = map.value(QStringLiteral("styles")).toList();
        for (const QVariant &styleEntry : list) {
            QVariantMap style = styleEntry.toMap();
            const QString file = style.value(QStringLiteral("file")).toString();
            const int index = style.value(QStringLiteral("index")).toInt();
            FT_Face face = nullptr;
            // The low half of fontconfig's index is the face in the file;
            // the high half a variable font's named style.
            if (FT_New_Face(freetype(), QFile::encodeName(file).constData(), index & 0xFFFF, &face) == 0) {
                style.insert(QStringLiteral("glyphs"), int(face->num_glyphs));
                style.insert(QStringLiteral("copyright"), sfntName(face, TT_NAME_ID_COPYRIGHT));
                style.insert(QStringLiteral("unique"), sfntName(face, TT_NAME_ID_UNIQUE_ID));
                style.insert(QStringLiteral("version"), sfntName(face, TT_NAME_ID_VERSION_STRING));
                style.insert(QStringLiteral("trademark"), sfntName(face, TT_NAME_ID_TRADEMARK));
                style.insert(QStringLiteral("manufacturer"), sfntName(face, TT_NAME_ID_MANUFACTURER));
                style.insert(QStringLiteral("designer"), sfntName(face, TT_NAME_ID_DESIGNER));
                style.insert(QStringLiteral("license"), sfntName(face, TT_NAME_ID_LICENSE));
                style.insert(QStringLiteral("embedding"), embedding(face));
                FT_Done_Face(face);
            }
            styles << style;
        }
        break;
    }
    QStringList languages;
    for (const QString &code : std::as_const(langs)) {
        const QString name = languageName(code);
        if (!name.isEmpty() && !languages.contains(name))
            languages << name;
    }
    languages.sort(Qt::CaseInsensitive);
    return {{QStringLiteral("styles"), styles}, {QStringLiteral("languages"), languages}};
}

QVariantMap Library::inspect(const QUrl &url)
{
    const QString file = url.isLocalFile() ? url.toLocalFile() : url.toString();
    QVariantMap result{{QStringLiteral("ok"), false}, {QStringLiteral("file"), file}, {QStringLiteral("name"), QFileInfo(file).fileName()}};
    FcFontSet *set = FcFontSetCreate();
    int count = 0;
    FcFreeTypeQueryAll(reinterpret_cast<const FcChar8 *>(QFile::encodeName(file).constData()), static_cast<unsigned int>(-1), nullptr, &count, set);
    QList<Face> faces;
    QSet<QString> instanced;
    for (int i = 0; i < set->nfont; ++i) {
        Face face = faceOf(set->fonts[i]);
        if (face.family.isEmpty())
            continue;
        if (!face.variable)
            instanced.insert(QString::number(face.index & 0xFFFF));
        faces << face;
    }
    FcFontSetDestroy(set);
    if (faces.isEmpty())
        return result;

    // Is each of its styles on the computer already?
    QSet<QString> have;
    for (const QVariant &entry : std::as_const(m_families)) {
        const QVariantMap map = entry.toMap();
        const QVariantList list = map.value(QStringLiteral("styles")).toList();
        for (const QVariant &style : list)
            have.insert(map.value(QStringLiteral("family")).toString() + QLatin1Char('\n') + style.toMap().value(QStringLiteral("name")).toString());
    }
    QVariantList styles;
    bool installed = true;
    QSet<QString> seen;
    for (const Face &face : std::as_const(faces)) {
        if (face.variable && instanced.contains(QString::number(face.index & 0xFFFF)))
            continue;
        QVariantMap style = styleMap(face, false);
        const QString key = face.family + QLatin1Char('\n') + style.value(QStringLiteral("name")).toString();
        if (seen.contains(key))
            continue;
        seen.insert(key);
        style.insert(QStringLiteral("family"), face.family);
        styles << style;
        installed = installed && have.contains(key);
    }
    // Loaded into this app alone, so its sample draws in it.
    const int id = QFontDatabase::addApplicationFont(file);
    const QStringList loaded = id >= 0 ? QFontDatabase::applicationFontFamilies(id) : QStringList();
    result.insert(QStringLiteral("ok"), true);
    result.insert(QStringLiteral("family"), faces.first().family);
    result.insert(QStringLiteral("loaded"), loaded.isEmpty() ? faces.first().family : loaded.first());
    result.insert(QStringLiteral("styles"), styles);
    result.insert(QStringLiteral("scripts"), faces.first().scripts);
    result.insert(QStringLiteral("first"), faces.first().first);
    result.insert(QStringLiteral("color"), faces.first().color);
    result.insert(QStringLiteral("installed"), installed);
    return result;
}

QVariantMap Library::install(const QList<QUrl> &files)
{
    QStringList installed, failed;
    const QString folder = userFolder();
    QDir().mkpath(folder);
    if (!m_watcher->directories().contains(folder))
        m_watcher->addPath(folder);
    for (const QUrl &url : files) {
        const QString source = url.isLocalFile() ? url.toLocalFile() : url.toString();
        const QFileInfo info(source);
        // Is it a font at all?
        int count = 0;
        FcPattern *pattern = FcFreeTypeQuery(reinterpret_cast<const FcChar8 *>(QFile::encodeName(source).constData()), 0, nullptr, &count);
        if (!pattern) {
            failed << info.fileName();
            continue;
        }
        const QString family = named(pattern, FC_FAMILY, FC_FAMILYLANG);
        FcPatternDestroy(pattern);

        // Under its own name; a different file already there by that name
        // keeps it, and this one takes a number.
        QString target = folder + QLatin1Char('/') + info.fileName();
        bool there = false;
        for (int n = 2; QFileInfo::exists(target); ++n) {
            if (sameFile(source, target)) {
                there = true;
                break;
            }
            target = folder + QLatin1Char('/') + info.completeBaseName() + QLatin1Char(' ') + QString::number(n) + QLatin1Char('.') + info.suffix();
        }
        if (!there && !QFile::copy(source, target)) {
            failed << info.fileName();
            continue;
        }
        QFile::setPermissions(target, QFile::ReadOwner | QFile::WriteOwner | QFile::ReadGroup | QFile::ReadOther);
        // Qt read the fonts once, as the app started: this one is told to
        // it by hand so its samples draw.
        QFontDatabase::addApplicationFont(target);
        if (!installed.contains(family))
            installed << family;
    }
    m_settle->stop();
    refresh();
    return {{QStringLiteral("installed"), installed}, {QStringLiteral("failed"), failed}};
}

int Library::remove(const QString &family)
{
    QSet<QString> files;
    for (const QVariant &entry : std::as_const(m_families)) {
        const QVariantMap map = entry.toMap();
        if (map.value(QStringLiteral("family")).toString() != family)
            continue;
        const QVariantList list = map.value(QStringLiteral("styles")).toList();
        for (const QVariant &style : list) {
            const QString file = style.toMap().value(QStringLiteral("file")).toString();
            if (isUser(file))
                files.insert(file);
        }
    }
    int gone = 0;
    for (const QString &file : std::as_const(files)) {
        if (QFile::moveToTrash(file))
            ++gone;
    }
    m_settle->stop();
    refresh();
    return gone;
}

Repertoire::Repertoire(QObject *parent)
    : QAbstractListModel(parent)
{
}

void Repertoire::setFile(const QString &file)
{
    if (file == m_file)
        return;
    m_file = file;
    Q_EMIT sourceChanged();
    load();
}

void Repertoire::setIndex(int index)
{
    if (index == m_index)
        return;
    m_index = index;
    Q_EMIT sourceChanged();
    load();
}

void Repertoire::load()
{
    beginResetModel();
    m_codes.clear();
    FT_Face face = nullptr;
    if (!m_file.isEmpty() && FT_New_Face(freetype(), QFile::encodeName(m_file).constData(), m_index & 0xFFFF, &face) == 0) {
        FT_UInt glyph = 0;
        for (FT_ULong code = FT_Get_First_Char(face, &glyph); glyph != 0; code = FT_Get_Next_Char(face, code, &glyph)) {
            if (code < 0x21 || (code >= 0x7F && code <= 0xA0) || code > 0x10FFFF)
                continue;
            const QChar::Category category = QChar::category(char32_t(code));
            if (category == QChar::Other_Control || category == QChar::Other_Format || category == QChar::Separator_Space
                || category == QChar::Separator_Line || category == QChar::Separator_Paragraph || category == QChar::Other_Surrogate
                || category == QChar::Other_NotAssigned)
                continue;
            m_codes << char32_t(code);
        }
        FT_Done_Face(face);
    }
    endResetModel();
    Q_EMIT loaded();
}

int Repertoire::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_codes.size();
}

QVariant Repertoire::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_codes.size())
        return {};
    const char32_t code = m_codes.at(index.row());
    if (role == GlyphRole) {
        // A mark that joins the letter before it is shown on a dotted ring.
        const QChar::Category category = QChar::category(code);
        const QString glyph = QString::fromUcs4(&code, 1);
        if (category == QChar::Mark_NonSpacing || category == QChar::Mark_Enclosing)
            return QString(QChar(0x25CC)) + glyph;
        return glyph;
    }
    if (role == CodeRole)
        return int(code);
    return {};
}

QHash<int, QByteArray> Repertoire::roleNames() const
{
    return {{GlyphRole, "glyph"}, {CodeRole, "code"}};
}
