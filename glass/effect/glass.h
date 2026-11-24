/*
    SPDX-FileCopyrightText: 2010 Fredrik Höglund <fredrik@kde.org>
    SPDX-FileCopyrightText: 2018 Alex Nemeth <alex.nemeth329@gmail.com>
    SPDX-FileCopyrightText: 2026 Justin Lee

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include "protocol.h"

#include "effect/effect.h"
#include "opengl/glutils.h"
#include "scene/item.h"

#include <QList>
#include <QVector3D>
#include <QVector4D>

#include <memory>
#include <optional>
#include <unordered_map>
#include <vector>

namespace KWin
{
class BackgroundEffectItem;
class SurfaceInterface;
}

namespace Ambrosia
{

/// The offscreen textures one sheet of glass blurs in, on one view: the
/// first holds the background as it is, cached; each next one half the size.
struct GlassRender
{
    std::vector<std::unique_ptr<KWin::GLTexture>> textures;
    std::vector<std::unique_ptr<KWin::GLFramebuffer>> framebuffers;
};

/// One blurred place in a window, in the window's coordinates: a pane the
/// client named (ambrosia_glass_v1), or all of a blur region asked for by
/// another protocol.
struct Sheet
{
    /// What is blurred, and the same as rectangles.
    KWin::RectF rect;
    KWin::RegionF shape;
    /// A pane's rounded outline. A region is cut to the window's own
    /// corners instead, where it has any.
    bool pane = false;
    KWin::RectF box;
    qreal radius = 0;
    /// Which of the design's materials (Tokens::materials).
    int material = 0;
    qreal opacity = 1;

    std::unique_ptr<KWin::BackgroundEffectItem> item;
    std::unordered_map<KWin::RenderView *, GlassRender> render;
};

struct WindowGlass
{
    /// The region to blur behind the window, and behind its frame, as other
    /// protocols ask (KWin's blur's own bookkeeping).
    std::optional<KWin::RegionF> content;
    std::optional<KWin::RegionF> frame;
    /// A pane one of KWin's own windows names (its ambrosia_glass_pane
    /// property): it isn't a Wayland client, so it can't speak the protocol.
    std::optional<Pane> own;

    std::vector<Sheet> sheets;
};

/**
 * Ambrosia's glass, in KWin's blur's place: what is behind each pane of a
 * surface is blurred and saturated as the pane's material asks, inside the
 * pane's rounded outline. A surface that only asks for a blur region (other
 * apps) gets one material for all of it, as KWin's blur would give.
 *
 * Forked from KWin 6.8's blur effect (src/plugins/blur).
 */
class GlassEffect : public KWin::Effect
{
    Q_OBJECT

public:
    GlassEffect();
    ~GlassEffect() override;

    static bool supported();

    void reconfigure(ReconfigureFlags flags) override;
    void prePaintScreen(KWin::ScreenPrePaintData &data) override;
    bool drawWindow(const KWin::RenderTarget &renderTarget, const KWin::RenderViewport &viewport, KWin::EffectWindow *w, int mask, const KWin::Region &deviceRegion, KWin::WindowPaintData &data) override;

    bool provides(Feature feature) override;
    bool isActive() const override;

    int requestedEffectChainPosition() const override
    {
        return 20;
    }

    bool eventFilter(QObject *watched, QEvent *event) override;

    bool blocksDirectScanout() const override;

public Q_SLOTS:
    void slotWindowAdded(KWin::EffectWindow *w);
    void slotWindowDeleted(KWin::EffectWindow *w);
    void slotViewRemoved(KWin::RenderView *view);
#if KWIN_BUILD_X11
    void slotPropertyNotify(KWin::EffectWindow *w, long atom);
#endif
    void setupDecorationConnections(KWin::EffectWindow *w);

private:
    void retireBlur();
    KWin::RegionF blurRegion(KWin::EffectWindow *w, const WindowGlass &glass) const;
    KWin::RegionF decorationBlurRegion(const KWin::EffectWindow *w) const;
    bool decorationSupportsBlurBehind(const KWin::EffectWindow *w) const;
    bool shouldBlur(const KWin::EffectWindow *w, int mask, const KWin::WindowPaintData &data) const;
    void updateWindow(KWin::EffectWindow *w);
    void layOut(KWin::EffectWindow *w, WindowGlass &glass);
    void forget(KWin::EffectWindow *w);
    void drawSheet(Sheet &sheet, const KWin::RenderTarget &renderTarget, const KWin::RenderViewport &viewport, KWin::EffectWindow *w, const KWin::Region &deviceRegion, KWin::WindowPaintData &data);

private:
    struct
    {
        std::unique_ptr<KWin::GLShader> shader;
        int mvpMatrixLocation;
        int colorMatrixLocation;
        int offsetLocation;
        int halfpixelLocation;
        int boxLocation;
        int cornerRadiusLocation;
        int opacityLocation;
        int noiseLocation;
        int rimLocation;
        int texelLocation;
    } m_onscreenPass;

    struct
    {
        std::unique_ptr<KWin::GLShader> shader;
        int mvpMatrixLocation;
        int offsetLocation;
        int halfpixelLocation;
    } m_downsamplePass;

    struct
    {
        std::unique_ptr<KWin::GLShader> shader;
        int mvpMatrixLocation;
        int offsetLocation;
        int halfpixelLocation;
    } m_upsamplePass;

    bool m_valid = false;
    bool m_retiring = false;
#if KWIN_BUILD_X11
    long net_wm_blur_region = 0;
#endif
    KWin::RenderView *m_currentView = nullptr;

    /// Each material's saturation as a color matrix, in Tokens' order.
    QList<QMatrix4x4> m_colorMatrices;

    QMap<KWin::EffectWindow *, QMetaObject::Connection> windowBlurChangedConnections;
    std::unordered_map<KWin::EffectWindow *, WindowGlass> m_windows;
};

inline bool GlassEffect::provides(Effect::Feature feature)
{
    if (feature == Blur) {
        return true;
    }
    return KWin::Effect::provides(feature);
}

} // namespace Ambrosia
