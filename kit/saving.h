#pragma once

#include <QObject>
#include <QQuickWindow>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// What the Save panel (SavePanel.qml, shown by Saving.qml) asks of the
// system: the folders at hand for its Where pop-up, whether a file is
// there already, the full panel when any other folder is wanted (Files',
// by the desktop portal), and the panel's shadow. An app that saves
// through the panel lists this header and saving.cpp among its QML
// module's sources.
class Places : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit Places(QObject *parent = nullptr);

    // The Desktop, Documents, Downloads and the home folder: [{ name, path }].
    Q_INVOKABLE QVariantList list() const;
    Q_INVOKABLE QString documents() const;
    Q_INVOKABLE QString desktop() const;
    // A folder's name as it is shown.
    Q_INVOKABLE QString name(const QString &folder) const;
    Q_INVOKABLE bool exists(const QString &path) const;
    Q_INVOKABLE bool isFolder(const QString &path) const;
    // A path as the address apps hand their writers.
    Q_INVOKABLE QUrl url(const QString &path) const;
    // The full Save panel, opened at `folder` with `name` typed in it and
    // `filter` ("PDF (*.pdf)") as the kind: `browsed` with `id` and the
    // path chosen, or "" when it was cancelled.
    Q_INVOKABLE void browse(int id, const QString &folder, const QString &name, const QString &filter);
    // The shadow KWin draws round the panel (the app's own shadow.cpp).
    Q_INVOKABLE void shade(QQuickWindow *window, int radius);

Q_SIGNALS:
    void browsed(int id, const QString &path);
};
