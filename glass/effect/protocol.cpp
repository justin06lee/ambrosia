/*
    SPDX-FileCopyrightText: 2026 Justin Lee

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "protocol.h"

#include "tokens.h"

#include "wayland/display.h"
#include "wayland/surface.h"
#include "wayland_server.h"

#include <wayland-server-core.h>

extern "C" {
#include "ambrosia-glass-v1-server.h"
}

#include <algorithm>

namespace Ambrosia
{

/// What stands behind one ambrosia_glass_v1 object.
struct GlassResource
{
    KWin::SurfaceInterface *surface = nullptr;
    QList<Pane> pending;
    bool dirty = false;
};

// A surface's panes are few (the shell's busiest has a dozen or so).
static const int s_mostPanes = 256;

static void glassDestroy(wl_client *, wl_resource *resource)
{
    wl_resource_destroy(resource);
}

static void glassClear(wl_client *, wl_resource *resource)
{
    auto glass = static_cast<GlassResource *>(wl_resource_get_user_data(resource));
    glass->pending.clear();
    glass->dirty = true;
}

static void glassAddPane(wl_client *, wl_resource *resource, wl_fixed_t x, wl_fixed_t y, wl_fixed_t width, wl_fixed_t height,
                         wl_fixed_t radius, uint32_t material, wl_fixed_t opacity,
                         wl_fixed_t clipX, wl_fixed_t clipY, wl_fixed_t clipWidth, wl_fixed_t clipHeight)
{
    auto glass = static_cast<GlassResource *>(wl_resource_get_user_data(resource));
    glass->dirty = true;
    if (glass->pending.size() >= s_mostPanes) {
        return;
    }
    Pane pane;
    pane.rect = KWin::RectF(wl_fixed_to_double(x), wl_fixed_to_double(y), wl_fixed_to_double(width), wl_fixed_to_double(height));
    pane.clip = KWin::RectF(wl_fixed_to_double(clipX), wl_fixed_to_double(clipY), wl_fixed_to_double(clipWidth), wl_fixed_to_double(clipHeight));
    if (pane.rect.width() <= 0 || pane.rect.height() <= 0 || pane.clip.width() <= 0 || pane.clip.height() <= 0) {
        return;
    }
    pane.radius = std::clamp(wl_fixed_to_double(radius), 0.0, std::min(pane.rect.width(), pane.rect.height()) / 2);
    pane.material = material < uint32_t(Tokens::materialCount) ? int(material) : Tokens::fallbackMaterial;
    pane.opacity = std::clamp(wl_fixed_to_double(opacity), 0.0, 1.0);
    glass->pending.append(pane);
}

static const struct ambrosia_glass_v1_interface s_glassRequests = {
    .destroy = glassDestroy,
    .clear = glassClear,
    .add_pane = glassAddPane,
};

static void glassGone(wl_resource *resource)
{
    auto glass = static_cast<GlassResource *>(wl_resource_get_user_data(resource));
    GlassProtocol::self()->detach(glass);
    delete glass;
}

static void managerDestroy(wl_client *, wl_resource *resource)
{
    wl_resource_destroy(resource);
}

static void managerGetGlass(wl_client *client, wl_resource *resource, uint32_t id, wl_resource *surfaceResource)
{
    wl_resource *made = wl_resource_create(client, &ambrosia_glass_v1_interface, wl_resource_get_version(resource), id);
    if (!made) {
        wl_client_post_no_memory(client);
        return;
    }
    auto glass = new GlassResource;
    wl_resource_set_implementation(made, &s_glassRequests, glass, glassGone);
    if (KWin::SurfaceInterface *surface = KWin::SurfaceInterface::get(surfaceResource)) {
        GlassProtocol::self()->attach(surface, glass);
    }
}

static const struct ambrosia_glass_manager_v1_interface s_managerRequests = {
    .destroy = managerDestroy,
    .get_glass = managerGetGlass,
};

static void managerBind(wl_client *client, void *, uint32_t version, uint32_t id)
{
    wl_resource *made = wl_resource_create(client, &ambrosia_glass_manager_v1_interface, version, id);
    if (!made) {
        wl_client_post_no_memory(client);
        return;
    }
    wl_resource_set_implementation(made, &s_managerRequests, nullptr, nullptr);
}

GlassProtocol *GlassProtocol::self()
{
    // Never deleted: clients' objects call into it until KWin itself ends
    // (the plugin is linked never to be unloaded, for the same reason).
    static GlassProtocol *s_self = new GlassProtocol;
    return s_self;
}

GlassProtocol::GlassProtocol()
{
    wl_display *display = *KWin::waylandServer()->display();
    m_global = wl_global_create(display, &ambrosia_glass_manager_v1_interface, 1, nullptr, managerBind);
}

bool GlassProtocol::has(KWin::SurfaceInterface *surface) const
{
    auto it = m_surfaces.constFind(surface);
    return it != m_surfaces.constEnd() && it->applied;
}

QList<Pane> GlassProtocol::panes(KWin::SurfaceInterface *surface) const
{
    return m_surfaces.value(surface).panes;
}

void GlassProtocol::attach(KWin::SurfaceInterface *surface, GlassResource *glass)
{
    Entry &entry = m_surfaces[surface];
    if (entry.glass) {
        // The newer object takes the surface over.
        entry.glass->surface = nullptr;
    }
    entry.glass = glass;
    glass->surface = surface;
    // What the surface shows stays until its next commit, which brings the
    // new object's panes (or none): until then a blur region it asked for
    // otherwise, or an older object's panes.
    glass->dirty = true;
    connect(surface, &KWin::SurfaceInterface::committed, this, &GlassProtocol::surfaceCommitted, Qt::UniqueConnection);
    connect(surface, &KWin::SurfaceInterface::aboutToBeDestroyed, this, &GlassProtocol::surfaceGoing, Qt::UniqueConnection);
}

void GlassProtocol::detach(GlassResource *glass)
{
    KWin::SurfaceInterface *surface = glass->surface;
    if (!surface) {
        return;
    }
    glass->surface = nullptr;
    // The panes stay until the surface is next committed: a window that is
    // closing lets go of its glass a moment before its surface, and must not
    // be drawn once more without it.
    if (auto it = m_surfaces.find(surface); it != m_surfaces.end() && it->glass == glass) {
        it->glass = nullptr;
        if (!it->applied) {
            m_surfaces.erase(it);
        }
    }
}

void GlassProtocol::surfaceCommitted()
{
    auto surface = static_cast<KWin::SurfaceInterface *>(sender());
    auto it = m_surfaces.find(surface);
    if (it == m_surfaces.end()) {
        return;
    }
    if (!it->glass) {
        // Its glass object went since the last commit.
        m_surfaces.erase(it);
        Q_EMIT changed(surface);
        return;
    }
    if (!it->glass->dirty) {
        return;
    }
    it->glass->dirty = false;
    if (!it->applied || it->panes != it->glass->pending) {
        it->applied = true;
        it->panes = it->glass->pending;
        Q_EMIT changed(surface);
    }
}

void GlassProtocol::surfaceGoing()
{
    auto surface = static_cast<KWin::SurfaceInterface *>(sender());
    auto it = m_surfaces.find(surface);
    if (it == m_surfaces.end()) {
        return;
    }
    if (it->glass) {
        it->glass->surface = nullptr;
    }
    // Nothing is told: the window goes with its surface, and keeps its glass
    // while it does (a closing animation).
    m_surfaces.erase(it);
}

} // namespace Ambrosia

#include "moc_protocol.cpp"
