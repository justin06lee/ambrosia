#pragma once

#include <QPointer>
#include <QQmlParserStatus>
#include <QQuickItem>

namespace Ambrosia
{

// Blur behind an item of one of KWin's own windows (⌘Tab's strip). Such a
// window isn't a Wayland client, so it can't ask for blur the way the shell
// does; KWin's blur takes a region for it from KWindowEffects, which QML
// can't reach. This gives it the item's rounded outline, kept current as the
// item moves and resizes. Ambrosia's glass effect is told more, as a
// property of the window it reads (ambrosia_glass_pane): the same outline as
// a pane of glass, and of which material.
class BlurBehind : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QQuickItem *item READ item WRITE setItem NOTIFY itemChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    // One of the design's materials by name: thin, regular, thick, clear.
    Q_PROPERTY(QString material READ material WRITE setMaterial NOTIFY materialChanged)

public:
    explicit BlurBehind(QObject *parent = nullptr);
    ~BlurBehind() override;

    QQuickItem *item() const;
    void setItem(QQuickItem *item);
    qreal radius() const;
    void setRadius(qreal radius);
    QString material() const;
    void setMaterial(const QString &material);

    void classBegin() override;
    void componentComplete() override;

Q_SIGNALS:
    void itemChanged();
    void radiusChanged();
    void materialChanged();

private:
    void update();
    void clear();

    QPointer<QQuickItem> m_item;
    QPointer<QWindow> m_window;
    qreal m_radius = 0;
    QString m_material = QStringLiteral("regular");
    bool m_complete = false;
};

}
