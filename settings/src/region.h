#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Language & Region, the user's own, in plasma-localerc (Plasma's start reads
// it, so a change shows from the next login): preferred languages, and the
// region that formats dates and numbers. The system's locale isn't touched.
class Region : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{value, text}], the first being primary.
    Q_PROPERTY(QVariantList languages READ languages NOTIFY changed)
    // [{value, text}], those not chosen.
    Q_PROPERTY(QVariantList available READ available CONSTANT)
    Q_PROPERTY(QString region READ region NOTIFY changed)
    // [{value, text}], the locales generated on this system.
    Q_PROPERTY(QVariantList regions READ regions CONSTANT)
    Q_PROPERTY(QString sampleLong READ sampleLong NOTIFY changed)
    Q_PROPERTY(QString sampleShort READ sampleShort NOTIFY changed)
    Q_PROPERTY(QString sampleNumbers READ sampleNumbers NOTIFY changed)
    Q_PROPERTY(QString firstDay READ firstDay NOTIFY changed)
    Q_PROPERTY(QString dateFormat READ dateFormat NOTIFY changed)
    Q_PROPERTY(QString numberFormat READ numberFormat NOTIFY changed)

public:
    explicit Region(QObject *parent = nullptr);

    QVariantList languages() const;
    QVariantList available() const;
    QString region() const;
    QVariantList regions() const;
    QString sampleLong() const;
    QString sampleShort() const;
    QString sampleNumbers() const;
    QString firstDay() const;
    QString dateFormat() const;
    QString numberFormat() const;

    Q_INVOKABLE void addLanguage(const QString &code);
    Q_INVOKABLE void removeLanguage(const QString &code);
    Q_INVOKABLE void setRegion(const QString &value);

Q_SIGNALS:
    void changed();
};
