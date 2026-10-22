#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// What the sidebar lists, in Finder's sections: the top items, Favorites,
// Locations and Tags. Each item is {name, url, glyph} (tags: {name, color}).
class Places : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QVariantList sections READ sections NOTIFY sectionsChanged)
    Q_PROPERTY(QString computer READ computer CONSTANT)

public:
    explicit Places(QObject *parent = nullptr);
    QVariantList sections() const;
    QString computer() const;

Q_SIGNALS:
    void sectionsChanged();
};
