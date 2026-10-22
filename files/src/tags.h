#pragma once

#include <QList>
#include <QObject>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QQmlEngine;
class QJSEngine;

// Finder's tags. An item's tags are its user.xdg.tags attribute, names
// separated by commas, as Dolphin and Baloo keep them, so both apps see the
// same tags. Which tags there are, in the sidebar's order, and their colors
// are kept in ~/.config/ambrosia/files/tags.json; Finder's seven colored
// tags come first.
class Tags : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{name, color}], color "red" … "gray", or "" for a tag without one.
    Q_PROPERTY(QVariantList all READ all NOTIFY listChanged)

public:
    static Tags *instance();
    static Tags *create(QQmlEngine *, QJSEngine *);

    QVariantList all() const;

    // An item's tags, read from the file (local paths).
    static QStringList read(const QString &path);
    // The colors of the tags among names that have one, in order.
    QStringList colorsOf(const QStringList &names) const;
    Q_INVOKABLE QString colorOf(const QString &name) const;
    Q_INVOKABLE QStringList of(const QUrl &url) const;
    // The tags every one of urls has (what File > Tags checks).
    Q_INVOKABLE QStringList common(const QList<QUrl> &urls) const;
    // Gives every item the tag, or takes it from all when all have it.
    Q_INVOKABLE void toggle(const QList<QUrl> &urls, const QString &name);
    Q_INVOKABLE void add(const QList<QUrl> &urls, const QString &name);
    Q_INVOKABLE void remove(const QList<QUrl> &urls, const QString &name);

Q_SIGNALS:
    void listChanged();
    // These items' tags changed.
    void changed(const QList<QUrl> &urls);

private:
    explicit Tags(QObject *parent = nullptr);
    void load();
    void save() const;
    void edit(const QList<QUrl> &urls, const QString &name, bool on);

    struct Tag {
        QString name;
        QString color;
    };
    QList<Tag> m_tags;
};
