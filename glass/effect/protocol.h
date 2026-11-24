/*
    SPDX-FileCopyrightText: 2026 Justin Lee

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include "core/rect.h"

#include <QHash>
#include <QList>
#include <QObject>
#include <QVariantList>

struct wl_client;
struct wl_global;
struct wl_resource;

namespace KWin
{
class SurfaceInterface;
}

namespace Ambrosia
{

/// One pane of glass in a surface, in the surface's own coordinates.
struct Pane
{
    KWin::RectF rect;
    KWin::RectF clip;
    qreal radius = 0;
    int material = 0;
    qreal opacity = 1;

    bool operator==(const Pane &other) const = default;
};

struct GlassResource;

/**
 * The compositor's side of ambrosia_glass_v1: which panes of glass each
 * surface has. It is made when the effect first loads and then lives as long
 * as KWin does, whether or not the effect is loaded: clients keep their
 * objects, and an effect loaded again finds every pane as it stands.
 */
class GlassProtocol : public QObject
{
    Q_OBJECT

public:
    static GlassProtocol *self();

    /// Whether the surface has a glass object whose panes a commit has
    /// brought: they then stand in for any blur region it asks for.
    bool has(KWin::SurfaceInterface *surface) const;
    QList<Pane> panes(KWin::SurfaceInterface *surface) const;

    /// For QML that runs inside KWin and draws a window as a picture
    /// (Mission Control, the bar and the Dock): the window's panes, each a
    /// map of x, y, width, height, radius, opacity and material (a name),
    /// in the window's own coordinates. The singleton Panes of
    /// org.ambrosia.glass.kwin, there while this effect has been loaded.
    Q_INVOKABLE QVariantList panesOf(QObject *window) const;

    // For the requests' handlers.
    void attach(KWin::SurfaceInterface *surface, GlassResource *glass);
    void detach(GlassResource *glass);

Q_SIGNALS:
    void changed(KWin::SurfaceInterface *surface);
    /// The same, for QML: some window's panes are no longer what they were.
    void panesChanged();

private Q_SLOTS:
    void surfaceCommitted();
    void surfaceGoing();

private:
    explicit GlassProtocol();

    struct Entry
    {
        GlassResource *glass = nullptr;
        /// Whether a commit has brought the object's panes yet.
        bool applied = false;
        QList<Pane> panes;
    };
    QHash<KWin::SurfaceInterface *, Entry> m_surfaces;
    wl_global *m_global = nullptr;
};

} // namespace Ambrosia
