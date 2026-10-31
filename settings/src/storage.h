#pragma once

#include <QObject>
#include <QProcess>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Storage: the disk's use, and in the background at the lowest priority what
// takes it; while the page shows. And emptying the Trash automatically, KDE's
// own setting (ktrashrc), which its Trash acts on.
class Storage : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString volume READ volume CONSTANT)
    Q_PROPERTY(QString usedText READ usedText NOTIFY changed)
    Q_PROPERTY(qreal total READ total NOTIFY changed)
    // [{name, bytes (-1 until known), text}], the last being what's left over.
    Q_PROPERTY(QVariantList categories READ categories NOTIFY changed)
    Q_PROPERTY(bool emptyTrash READ emptyTrash WRITE setEmptyTrash NOTIFY changed)

public:
    explicit Storage(QObject *parent = nullptr);

    QString volume() const;
    QString usedText() const;
    qreal total() const;
    QVariantList categories() const;
    bool emptyTrash() const;
    void setEmptyTrash(bool on);

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

Q_SIGNALS:
    void changed();

private:
    void next();

    QProcess m_du;
    int m_scanning = -1;
    QList<qint64> m_sizes;
};
