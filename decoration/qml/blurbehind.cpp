#include "blurbehind.h"

#include <KWindowEffects>
#include <QPainterPath>
#include <QQuickWindow>
#include <QRegion>

namespace Ambrosia
{

BlurBehind::BlurBehind(QObject *parent)
    : QObject(parent)
{
}

BlurBehind::~BlurBehind()
{
    clear();
}

QQuickItem *BlurBehind::item() const
{
    return m_item;
}

void BlurBehind::setItem(QQuickItem *item)
{
    if (m_item == item) {
        return;
    }
    if (m_item) {
        m_item->disconnect(this);
    }
    m_item = item;
    if (m_item) {
        connect(m_item, &QQuickItem::xChanged, this, &BlurBehind::update);
        connect(m_item, &QQuickItem::yChanged, this, &BlurBehind::update);
        connect(m_item, &QQuickItem::widthChanged, this, &BlurBehind::update);
        connect(m_item, &QQuickItem::heightChanged, this, &BlurBehind::update);
        connect(m_item, &QQuickItem::windowChanged, this, &BlurBehind::update);
    }
    Q_EMIT itemChanged();
    update();
}

qreal BlurBehind::radius() const
{
    return m_radius;
}

void BlurBehind::setRadius(qreal radius)
{
    if (qFuzzyCompare(m_radius, radius)) {
        return;
    }
    m_radius = radius;
    Q_EMIT radiusChanged();
    update();
}

QString BlurBehind::material() const
{
    return m_material;
}

void BlurBehind::setMaterial(const QString &material)
{
    if (m_material == material) {
        return;
    }
    m_material = material;
    Q_EMIT materialChanged();
    update();
}

void BlurBehind::classBegin()
{
}

void BlurBehind::componentComplete()
{
    m_complete = true;
    update();
}

void BlurBehind::clear()
{
    if (m_window) {
        KWindowEffects::enableBlurBehind(m_window, false);
        m_window->setProperty("ambrosia_glass_pane", QVariant());
    }
    m_window = nullptr;
}

void BlurBehind::update()
{
    if (!m_complete) {
        return;
    }
    QWindow *window = m_item ? m_item->window() : nullptr;
    if (window != m_window) {
        clear();
        m_window = window;
    }
    if (!m_window || m_item->width() <= 0 || m_item->height() <= 0) {
        return;
    }
    const QRectF rect = m_item->mapRectToScene(QRectF(0, 0, m_item->width(), m_item->height()));
    const qreal radius = qBound(0.0, m_radius, qMin(rect.width(), rect.height()) / 2);
    QPainterPath outline;
    outline.addRoundedRect(rect, radius, radius);
    KWindowEffects::enableBlurBehind(m_window, true, QRegion(outline.toFillPolygon().toPolygon()));
    // For Ambrosia's glass effect, which draws the pane to its true corner:
    // x, y, width, height, radius, material.
    m_window->setProperty("ambrosia_glass_pane", QVariantList{rect.x(), rect.y(), rect.width(), rect.height(), radius, m_material});
}

}
