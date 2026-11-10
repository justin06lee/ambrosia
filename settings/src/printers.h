#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class QProcess;

// Printers & Scanners: what CUPS can print to. Its own queues and the
// printers it finds on the network by itself (which print without being
// added), the default printer and paper size (yours, in ~/.cups/lpoptions,
// as lpoptions sets them), and adding one by its address or removing one
// (lpadmin, which CUPS lets an administrator do). Reads run on a thread:
// looking for network printers takes a moment.
class Printers : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // False while the CUPS scheduler can't be reached.
    Q_PROPERTY(bool running READ running NOTIFY changed)
    // [{name, title, model, location, address, state ("idle", "printing",
    // "stopped", "nearby"), jobs, isDefault, added (a queue of CUPS's own,
    // which can be removed)}], by title.
    Q_PROPERTY(QVariantList printers READ printers NOTIFY changed)
    // The default printer's name, or "" (each app then offers the one it used last).
    Q_PROPERTY(QString defaultPrinter READ defaultPrinter WRITE setDefaultPrinter NOTIFY changed)
    // The default printer's paper (a PWG name: iso_a4_210x297mm), set on all.
    Q_PROPERTY(QString paper READ paper WRITE setPaper NOTIFY changed)
    // [{text, value}] of the sizes offered.
    Q_PROPERTY(QVariantList papers READ papers CONSTANT)
    Q_PROPERTY(bool adding READ adding NOTIFY addingChanged)

public:
    explicit Printers(QObject *parent = nullptr);

    bool running() const { return m_running; }
    QVariantList printers() const { return m_printers; }
    QString defaultPrinter() const { return m_default; }
    void setDefaultPrinter(const QString &name);
    QString paper() const { return m_paper; }
    void setPaper(const QString &paper);
    QVariantList papers() const;
    bool adding() const { return m_adding; }

    // A driverless (IPP Everywhere) printer at a host name or address, or a
    // whole ipp:// address: addDone(true, "") or addDone(false, why).
    Q_INVOKABLE void add(const QString &address, const QString &title, const QString &location);
    Q_INVOKABLE void remove(const QString &name);
    Q_INVOKABLE void printTestPage(const QString &name);
    // The queue name a printer's title makes (CUPS allows no spaces, / or #).
    Q_INVOKABLE QString queueName(const QString &title) const;

public Q_SLOTS:
    void read();

Q_SIGNALS:
    void changed();
    void addingChanged();
    void addDone(bool ok, const QString &message);

private:
    void run(const QString &program, const QStringList &arguments, const char *what);

    bool m_running = true;
    bool m_reading = false;
    bool m_again = false;
    bool m_adding = false;
    QVariantList m_printers;
    QString m_default;
    QString m_paper;
};
