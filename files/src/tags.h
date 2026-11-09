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
    // A tag's color ("red" … "gray", or "" for none), as the sidebar's
    // tag menu sets it.
    Q_INVOKABLE void setColor(const QString &name, const QString &color);
    // Puts each item's tags back as they were (Undo and Redo), without
    // recording it as an edit.
    void restore(const QList<QUrl> &urls, const QList<QStringList> &tags);

Q_SIGNALS:
    void listChanged();
    // These items' tags changed.
    void changed(const QList<QUrl> &urls);
    // An edit to record for Undo: the items and their tags before and after.
    void edited(const QList<QUrl> &urls, const QList<QStringList> &before, const QList<QStringList> &after);

private:
    explicit Tags(QObject *parent = nullptr);
    void load();
    void save() const;
    void edit(const QList<QUrl> &urls, const QString &name, bool on);
    static bool write(const QUrl &url, const QStringList &names);

    struct Tag {
        QString name;
        QString color;
    };
    QList<Tag> m_tags;
};
