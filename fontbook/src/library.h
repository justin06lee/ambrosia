#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QObject>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QFileSystemWatcher;
class QTimer;

// The computer's fonts, as fontconfig lists them: every typeface with its
// styles, the file each is in, which the user put there (the ones under
// ~/.local/share/fonts and ~/.fonts), what it can write. A font's own words
// about itself (copyright, version, how many glyphs) are read from its
// file with FreeType when asked for. Adding copies files into the user's
// font folder; removing moves them to the Trash. What is listed, in what
// order and in what words is qml/fontbook.mjs's.
class Library : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{ family, styles: [{ name, file, index, postscript, full, weight,
    // width, slant, format, user }], user, mono, color, format, scripts:
    // [key], first, langs: [code] }], families by name.
    Q_PROPERTY(QVariantList families READ families NOTIFY changed)
    // The languages the user reads, for the sidebar: [{ code, name }].
    Q_PROPERTY(QVariantList languages READ languages CONSTANT)
    // Where a user's own fonts go.
    Q_PROPERTY(QString userFolder READ userFolder CONSTANT)

public:
    explicit Library(QObject *parent = nullptr);

    QVariantList families() const { return m_families; }
    QVariantList languages() const;
    QString userFolder() const;

    // What a typeface's files say of each style: { styles: [{ name,
    // postscript, unique, version, glyphs, file, copyright, trademark,
    // embedding, format, user }], languages: [name] }.
    Q_INVOKABLE QVariantMap details(const QString &family) const;
    // A font file that may not be installed: { ok, family, styles: [{ name,
    // family, postscript }], installed, loaded } — `loaded` is the family
    // Qt draws it by from now on (the file is loaded into this app).
    Q_INVOKABLE QVariantMap inspect(const QUrl &file);
    // Copies font files into the user's folder: { installed: [family],
    // failed: [file name] }.
    Q_INVOKABLE QVariantMap install(const QList<QUrl> &files);
    // Moves a typeface's files to the Trash, those the user owns: how many
    // went.
    Q_INVOKABLE int remove(const QString &family);
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void changed();

private:
    QStringList userFolders() const;
    bool isUser(const QString &file) const;

    QVariantList m_families;
    QFileSystemWatcher *m_watcher = nullptr;
    QTimer *m_settle = nullptr;
};

// Every character a font's file has a glyph for, in code order: the
// repertoire a typeface's page shows. Spaces and controls are left out.
class Repertoire : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString file READ file WRITE setFile NOTIFY sourceChanged)
    Q_PROPERTY(int index READ index WRITE setIndex NOTIFY sourceChanged)
    Q_PROPERTY(int count READ count NOTIFY loaded)

public:
    enum Roles { GlyphRole = Qt::UserRole + 1, CodeRole };

    explicit Repertoire(QObject *parent = nullptr);

    QString file() const { return m_file; }
    void setFile(const QString &file);
    int index() const { return m_index; }
    void setIndex(int index);
    int count() const { return m_codes.size(); }

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

Q_SIGNALS:
    void sourceChanged();
    void loaded();

private:
    void load();

    QString m_file;
    int m_index = 0;
    QList<char32_t> m_codes;
};
