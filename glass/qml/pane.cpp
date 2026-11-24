// SPDX-FileCopyrightText: 2026 Justin Lee
// SPDX-License-Identifier: MIT

#include "pane.h"

#include <QGuiApplication>
#include <QPointer>
#include <QQuickWindow>
#include <qpa/qplatformwindow_p.h>

#include <wayland-client.h>

extern "C" {
#include "ambrosia-glass-v1-client.h"
}

#include <cstring>

namespace Ambrosia
{

// The protocol's materials, in its order.
static const char *const s_materials[] = {"thin", "regular", "thick", "clear", "backdrop"};
static const int s_regular = 1;

// The compositor's ambrosia_glass_manager_v1, if it has one. Found on Qt's
// own connection and its own queue: everything here runs on the GUI thread.
class GlassConnection : public QObject
{
    Q_OBJECT

public:
    static GlassConnection *self()
    {
        static GlassConnection *s_self = new GlassConnection;
        return s_self;
    }

    ambrosia_glass_manager_v1 *manager() const
    {
        return m_manager;
    }

Q_SIGNALS:
    void managerChanged();

private:
    GlassConnection()
    {
        auto wayland = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
        if (!wayland || !wayland->display()) {
            return;
        }
        static const wl_registry_listener listener = {
            .global = [](void *data, wl_registry *registry, uint32_t name, const char *interface, uint32_t) {
                auto self = static_cast<GlassConnection *>(data);
                if (!self->m_manager && std::strcmp(interface, ambrosia_glass_manager_v1_interface.name) == 0) {
                    self->m_manager = static_cast<ambrosia_glass_manager_v1 *>(wl_registry_bind(registry, name, &ambrosia_glass_manager_v1_interface, 1));
                    self->m_name = name;
                    Q_EMIT self->managerChanged();
                }
            },
            .global_remove = [](void *data, wl_registry *, uint32_t name) {
                auto self = static_cast<GlassConnection *>(data);
                if (self->m_manager && self->m_name == name) {
                    // The windows let go of their glass first.
                    ambrosia_glass_manager_v1 *gone = self->m_manager;
                    self->m_manager = nullptr;
                    Q_EMIT self->managerChanged();
                    ambrosia_glass_manager_v1_destroy(gone);
                }
            },
        };
        m_registry = wl_display_get_registry(wayland->display());
        wl_registry_add_listener(m_registry, &listener, this);
    }

    wl_registry *m_registry = nullptr;
    ambrosia_glass_manager_v1 *m_manager = nullptr;
    uint32_t m_name = 0;
};

// The panes of one window, and what the compositor was last told of them.
class GlassWindow : public QObject
{
    Q_OBJECT

public:
    static GlassWindow *of(QQuickWindow *window)
    {
        if (auto found = window->findChild<GlassWindow *>(QString(), Qt::FindDirectChildrenOnly)) {
            return found;
        }
        return new GlassWindow(window);
    }

    void add(GlassPane *pane)
    {
        m_panes.append(pane);
        m_window->update();
    }

    void remove(GlassPane *pane)
    {
        m_panes.removeOne(pane);
        m_window->update();
    }

private:
    // A pane as the protocol carries it (24.8 fixed point), to tell a real
    // change from one too small to send.
    struct Sent
    {
        wl_fixed_t x, y, width, height, radius, opacity, clipX, clipY, clipWidth, clipHeight;
        uint32_t material;
        bool operator==(const Sent &other) const = default;
    };

    explicit GlassWindow(QQuickWindow *window)
        : QObject(window)
        , m_window(window)
    {
        // On the GUI thread, once the frame's items are laid out and just
        // before it is drawn: what is sent here is applied with the frame.
        connect(window, &QQuickWindow::afterAnimating, this, &GlassWindow::sync);
        connect(GlassConnection::self(), &GlassConnection::managerChanged, this, [this]() {
            reset();
            m_window->update();
        });
    }

    ~GlassWindow() override
    {
        reset();
    }

    void reset()
    {
        if (m_glass) {
            ambrosia_glass_v1_destroy(m_glass);
            m_glass = nullptr;
        }
        m_sent.clear();
        m_told = false;
    }

    void sync()
    {
        ambrosia_glass_manager_v1 *manager = GlassConnection::self()->manager();
        if (!manager) {
            return;
        }
        // The glass belongs to the window's Wayland surface, which comes
        // and goes as the window is shown and hidden.
        auto native = m_window->nativeInterface<QNativeInterface::Private::QWaylandWindow>();
        if (native != m_native) {
            reset();
            if (m_native) {
                m_native->disconnect(this);
            }
            m_native = native;
            if (native) {
                connect(native, &QNativeInterface::Private::QWaylandWindow::surfaceDestroyed, this, &GlassWindow::reset);
            }
        }
        wl_surface *surface = native ? native->surface() : nullptr;
        if (!surface) {
            reset();
            return;
        }

        QList<Sent> now;
        const QRectF all(0, 0, m_window->width(), m_window->height());
        for (GlassPane *pane : std::as_const(m_panes)) {
            if (!pane->isVisible() || pane->width() <= 0 || pane->height() <= 0) {
                continue;
            }
            qreal opacity = 1;
            QRectF clip = all;
            for (QQuickItem *item = pane; item; item = item->parentItem()) {
                opacity *= item->opacity();
                if (item != pane && item->clip()) {
                    clip &= item->mapRectToScene(QRectF(0, 0, item->width(), item->height()));
                }
            }
            const QRectF rect = pane->mapRectToScene(QRectF(0, 0, pane->width(), pane->height()));
            clip &= rect;
            if (opacity < 0.004 || clip.isEmpty()) {
                continue;
            }
            // A pane scaled by something above it has its corners scaled too.
            const qreal radius = pane->radius() * rect.width() / pane->width();
            now.append({
                .x = wl_fixed_from_double(rect.x()),
                .y = wl_fixed_from_double(rect.y()),
                .width = wl_fixed_from_double(rect.width()),
                .height = wl_fixed_from_double(rect.height()),
                .radius = wl_fixed_from_double(radius),
                .opacity = wl_fixed_from_double(std::min(opacity, 1.0)),
                .clipX = wl_fixed_from_double(clip.x()),
                .clipY = wl_fixed_from_double(clip.y()),
                .clipWidth = wl_fixed_from_double(clip.width()),
                .clipHeight = wl_fixed_from_double(clip.height()),
                .material = uint32_t(pane->materialNumber()),
            });
        }

        if (!m_glass) {
            if (now.isEmpty()) {
                return;
            }
            m_glass = ambrosia_glass_manager_v1_get_glass(manager, surface);
        }
        if (m_told && now == m_sent) {
            return;
        }
        ambrosia_glass_v1_clear(m_glass);
        for (const Sent &pane : std::as_const(now)) {
            ambrosia_glass_v1_add_pane(m_glass, pane.x, pane.y, pane.width, pane.height, pane.radius, pane.material, pane.opacity,
                                       pane.clipX, pane.clipY, pane.clipWidth, pane.clipHeight);
        }
        m_sent = now;
        m_told = true;
    }

    QQuickWindow *m_window;
    QList<GlassPane *> m_panes;
    QPointer<QNativeInterface::Private::QWaylandWindow> m_native;
    ambrosia_glass_v1 *m_glass = nullptr;
    QList<Sent> m_sent;
    bool m_told = false;
};

GlassPane::GlassPane(QQuickItem *parent)
    : QQuickItem(parent)
{
}

GlassPane::~GlassPane()
{
    if (m_window) {
        GlassWindow::of(m_window)->remove(this);
    }
}

QString GlassPane::material() const
{
    return m_material;
}

void GlassPane::setMaterial(const QString &material)
{
    if (m_material == material) {
        return;
    }
    m_material = material;
    Q_EMIT materialChanged();
    changed();
}

qreal GlassPane::radius() const
{
    return m_radius;
}

void GlassPane::setRadius(qreal radius)
{
    if (qFuzzyCompare(m_radius, radius)) {
        return;
    }
    m_radius = radius;
    Q_EMIT radiusChanged();
    changed();
}

int GlassPane::materialNumber() const
{
    const QByteArray name = m_material.toLatin1();
    for (int i = 0; i < int(std::size(s_materials)); ++i) {
        if (name == s_materials[i]) {
            return i;
        }
    }
    return s_regular;
}

void GlassPane::itemChange(ItemChange change, const ItemChangeData &value)
{
    if (change == ItemSceneChange && value.window != m_window) {
        if (m_window) {
            GlassWindow::of(m_window)->remove(this);
        }
        m_window = value.window;
        if (m_window) {
            GlassWindow::of(m_window)->add(this);
        }
    }
    QQuickItem::itemChange(change, value);
}

void GlassPane::changed()
{
    // Nothing of a pane is drawn, so a change to it alone asks for a frame.
    if (m_window) {
        m_window->update();
    }
}

} // namespace Ambrosia

#include "pane.moc"
