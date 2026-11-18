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
// item moves and resizes.
class BlurBehind : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(QQuickItem *item READ item WRITE setItem NOTIFY itemChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)

public:
    explicit BlurBehind(QObject *parent = nullptr);
    ~BlurBehind() override;

    QQuickItem *item() const;
    void setItem(QQuickItem *item);
    qreal radius() const;
    void setRadius(qreal radius);

    void classBegin() override;
    void componentComplete() override;

Q_SIGNALS:
    void itemChanged();
    void radiusChanged();

private:
    void update();
    void clear();

    QPointer<QQuickItem> m_item;
    QPointer<QWindow> m_window;
    qreal m_radius = 0;
    bool m_complete = false;
};

}
