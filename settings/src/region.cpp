#include "region.h"

#include <KConfigGroup>
#include <KSharedConfig>
#include <QDateTime>
#include <QDir>
#include <QLocale>
#include <QProcess>
#include <QSet>
#include <QVariantMap>

using namespace Qt::StringLiterals;

namespace
{
KSharedConfigPtr config()
{
    return KSharedConfig::openConfig(u"plasma-localerc"_s);
}

QString currentRegion()
{
    return config()->group(u"Formats"_s).readEntry("LANG", qEnvironmentVariable("LANG", u"en_US.UTF-8"_s));
}

QLocale locale()
{
    return QLocale(currentRegion().section(u'.', 0, 0));
}

QStringList chosenLanguages()
{
    const QString saved = config()->group(u"Translations"_s).readEntry("LANGUAGE", QString());
    if (!saved.isEmpty())
        return saved.split(u':', Qt::SkipEmptyParts);
    return {currentRegion().section(u'.', 0, 0)};
}

void saveLanguages(const QStringList &languages)
{
    KConfigGroup group = config()->group(u"Translations"_s);
    group.writeEntry("LANGUAGE", languages.join(u':'), KConfig::Notify);
    group.sync();
}

QVariantMap languageEntry(const QString &code, bool primary = false)
{
    const QLocale language(code);
    const QString native = language.nativeLanguageName();
    const QString english = QLocale::languageToString(language.language());
    QString text = native.isEmpty() ? code : native.left(1).toUpper() + native.mid(1);
    if (code.contains(u'_'))
        text += u" ("_s + language.nativeTerritoryName() + u')';
    if (!english.isEmpty() && english != native)
        text += u" — "_s + english + (primary ? u" — Primary"_s : QString());
    else if (primary)
        text += u" — Primary"_s;
    return {{u"value"_s, code}, {u"text"_s, text}};
}
}

Region::Region(QObject *parent)
    : QObject(parent)
{
}

QVariantList Region::languages() const
{
    QVariantList list;
    const QStringList chosen = chosenLanguages();
    for (int i = 0; i < chosen.size(); ++i)
        list.append(languageEntry(chosen[i], i == 0));
    return list;
}

QVariantList Region::available() const
{
    // Those with translations installed.
    QVariantList list;
    const QStringList codes = QDir(u"/usr/share/locale"_s).entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const QString &code : codes) {
        if (code.contains(u'@') || code == "C"_L1 || !QDir(u"/usr/share/locale/"_s + code + u"/LC_MESSAGES"_s).exists())
            continue;
        if (QLocale(code).language() == QLocale::C)
            continue;
        list.append(languageEntry(code));
    }
    return list;
}

QString Region::region() const
{
    return currentRegion();
}

QVariantList Region::regions() const
{
    QVariantList list;
    QProcess locales;
    locales.start(u"locale"_s, {u"-a"_s});
    locales.waitForFinished(3000);
    const QStringList names = QString::fromLocal8Bit(locales.readAllStandardOutput()).split(u'\n', Qt::SkipEmptyParts);
    QSet<QString> seen;
    for (const QString &name : names) {
        if (!name.contains(u'_') || !name.contains("utf8"_L1, Qt::CaseInsensitive) && !name.contains("utf-8"_L1, Qt::CaseInsensitive))
            continue;
        const QString base = name.section(u'.', 0, 0);
        if (seen.contains(base))
            continue;
        seen.insert(base);
        const QLocale each(base);
        list.append(QVariantMap{{u"text"_s, QLocale::territoryToString(each.territory())}, {u"value"_s, base + u".UTF-8"_s}});
    }
    // What's set stays on the list, generated or not.
    if (!seen.contains(currentRegion().section(u'.', 0, 0))) {
        const QLocale each = locale();
        list.append(QVariantMap{{u"text"_s, QLocale::territoryToString(each.territory())}, {u"value"_s, currentRegion()}});
    }
    return list;
}

QString Region::sampleLong() const
{
    return locale().toString(QDateTime::currentDateTime(), QLocale::LongFormat);
}

QString Region::sampleShort() const
{
    return locale().toString(QDateTime::currentDateTime(), QLocale::ShortFormat);
}

QString Region::sampleNumbers() const
{
    const QLocale here = locale();
    return here.toCurrencyString(12345.67) + u"   "_s + here.toString(4567.89, 'f', 2);
}

QString Region::firstDay() const
{
    return QLocale().standaloneDayName(int(locale().firstDayOfWeek()), QLocale::LongFormat);
}

QString Region::dateFormat() const
{
    return locale().toString(QDate(2026, 8, 19), QLocale::ShortFormat);
}

QString Region::numberFormat() const
{
    return locale().toString(1234567.89, 'f', 2);
}

void Region::addLanguage(const QString &code)
{
    QStringList chosen = chosenLanguages();
    if (!chosen.contains(code))
        chosen.append(code);
    saveLanguages(chosen);
    Q_EMIT changed();
}

void Region::removeLanguage(const QString &code)
{
    QStringList chosen = chosenLanguages();
    chosen.removeAll(code);
    if (chosen.isEmpty())
        return;
    saveLanguages(chosen);
    Q_EMIT changed();
}

void Region::setRegion(const QString &value)
{
    KConfigGroup group = config()->group(u"Formats"_s);
    group.writeEntry("LANG", value, KConfig::Notify);
    // A single region here, not one per format.
    for (const auto key : {"LC_ADDRESS", "LC_MEASUREMENT", "LC_MONETARY", "LC_NAME", "LC_NUMERIC", "LC_PAPER", "LC_TELEPHONE", "LC_TIME"})
        group.deleteEntry(key);
    group.sync();
    Q_EMIT changed();
}
