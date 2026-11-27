#pragma once

#include <QObject>
#include <QQuickWindow>
#include <QSizeF>
#include <QString>
#include <QTemporaryDir>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include <memory>

class QJSEngine;
class QQmlEngine;

// What the Print panel (PrintPanel.qml, shown by Printing.qml) asks of the
// system: the printers CUPS knows, the papers one of them takes, a PDF's
// pages as pictures (image://printing/ID/PAGE) and the sending of a PDF to
// a printer. Everything that waits on CUPS runs off the main thread and
// answers by a signal. An app that prints lists this header and
// printing.cpp among its QML module's sources and links CUPS and Qt's PDF
// library.
class Cups : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{ name, title, isDefault }], by title.
    Q_PROPERTY(QVariantList printers READ printers NOTIFY changed)
    // The printers have been asked for and the answer is in.
    Q_PROPERTY(bool looked READ looked NOTIFY changed)

public:
    ~Cups() override;
    // How the engine makes it (the constructor is out of its reach, or it
    // would use that): the pages' pictures are made known to it here.
    static Cups *create(QQmlEngine *engine, QJSEngine *);

    QVariantList printers() const { return m_printers; }
    bool looked() const { return m_looked; }

    // Reads the printers again; `changed` when they are in.
    Q_INVOKABLE void look();
    // The papers a printer takes, of those we name, and the one it uses
    // unless told: `told` when known.
    Q_INVOKABLE void ask(const QString &printer);
    // The papers we name: [{ key, name, note, width, height }], the size
    // in points. `key` is the name CUPS knows it by.
    Q_INVOKABLE QVariantList papers() const;
    // The paper of the region: A4, or US Letter.
    Q_INVOKABLE QString usual() const;

    // A new file's address for a PDF to print, gone when the app quits.
    Q_INVOKABLE QUrl scratch();
    Q_INVOKABLE void discard(const QUrl &file);
    // A PDF's pages, to show: { id, pages: [{ width, height }] } (points).
    // The pictures are image://printing/ID/PAGE until `close`.
    Q_INVOKABLE QVariantMap open(const QUrl &file);
    Q_INVOKABLE void close(const QString &id);

    // Sends a PDF. `options`: copies, from and to (pages, from 1; both or
    // neither), paper (a key), landscape and fit (for a PDF whose pages
    // aren't made for the paper). `sent` says how it went.
    Q_INVOKABLE void send(const QString &printer, const QUrl &file, const QString &title, const QVariantMap &options);
    // Opens a PDF in Preview, under a name.
    Q_INVOKABLE void preview(const QUrl &file, const QString &title);
    // Settings' Printers & Scanners.
    Q_INVOKABLE void settings();
    // The shadow KWin draws round the panel (the app's own shadow.cpp).
    Q_INVOKABLE void shade(QQuickWindow *window, int radius);

Q_SIGNALS:
    void changed();
    void told(const QString &printer, const QVariantList &papers, const QString &usual);
    void sent(bool ok, const QString &why);

private:
    explicit Cups(QObject *parent = nullptr);
    QString folder();

    QVariantList m_printers;
    bool m_looked = false;
    bool m_looking = false;
    std::unique_ptr<QTemporaryDir> m_folder;
    int m_files = 0;
    int m_opened = 0;
};
