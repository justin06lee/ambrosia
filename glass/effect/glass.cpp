/*
    SPDX-FileCopyrightText: 2010 Fredrik Höglund <fredrik@kde.org>
    SPDX-FileCopyrightText: 2011 Philipp Knechtges <philipp-dev@knechtges.com>
    SPDX-FileCopyrightText: 2018 Alex Nemeth <alex.nemeth329@gmail.com>
    SPDX-FileCopyrightText: 2026 Justin Lee

    SPDX-License-Identifier: GPL-2.0-or-later
*/

// Forked from KWin 6.8's blur effect (src/plugins/blur/blur.cpp). What is
// ours: a window's blur is a list of sheets, each with its own material
// (blur, saturation), outline and opacity, where KWin has one region and one
// setting for everything; the sheets come from ambrosia_glass_v1 (protocol.h)
// where a surface speaks it; the grain is drawn in the last pass.

#include "glass.h"
#include "protocol.h"
#include "tokens.h"

#include "core/rendertarget.h"
#include "core/renderviewport.h"
#include "effect/effecthandler.h"
#include "opengl/glplatform.h"
#include "scene/backgroundeffectitem.h"
#include "scene/decorationitem.h"
#include "scene/scene.h"
#include "scene/surfaceitem.h"
#include "scene/windowitem.h"
#include "wayland/backgroundeffect_v1.h"
#include "wayland/display.h"
#include "wayland/surface.h"
#include "wayland_server.h"
#include "window.h"

#if KWIN_BUILD_X11
#include "utils/xcbutils.h"
#include "x11window.h"
#endif

#include <QGuiApplication>
#include <QLoggingCategory>
#include <QMatrix4x4>
#include <QTimer>
#include <QWindow>
#include <cmath>

#include <KDecoration3/Decoration>

Q_LOGGING_CATEGORY(AMBROSIA_GLASS, "ambrosia_glass", QtWarningMsg)

using namespace KWin;

namespace Ambrosia
{

static const QByteArray s_blurAtomName = QByteArrayLiteral("_KDE_NET_WM_BLUR_BEHIND_REGION");
static const QString s_blur = QStringLiteral("blur");

static QMatrix4x4 saturationMatrix(qreal saturation)
{
    if (qFuzzyCompare(saturation, 1.0)) {
        return QMatrix4x4();
    }
    const qreal rval = (1.0 - saturation) * 0.2126;
    const qreal gval = (1.0 - saturation) * 0.7152;
    const qreal bval = (1.0 - saturation) * 0.0722;

    return QMatrix4x4(rval + saturation, rval, rval, 0.0,
                      gval, gval + saturation, gval, 0.0,
                      bval, bval, bval + saturation, 0.0,
                      0.0, 0.0, 0.0, 1.0);
}

GlassEffect::GlassEffect()
{
    const QString shaders = QStringLiteral(":/effects/ambrosia_glass/shaders/");

    m_onscreenPass.shader = ShaderManager::instance()->generateShaderFromFile(ShaderTrait::MapTexture,
                                                                              shaders + QStringLiteral("onscreen.vert"),
                                                                              shaders + QStringLiteral("onscreen.frag"));
    if (!m_onscreenPass.shader) {
        qCWarning(AMBROSIA_GLASS) << "Failed to load onscreen pass shader";
        return;
    } else {
        m_onscreenPass.mvpMatrixLocation = m_onscreenPass.shader->uniformLocation("modelViewProjectionMatrix");
        m_onscreenPass.colorMatrixLocation = m_onscreenPass.shader->uniformLocation("colorMatrix");
        m_onscreenPass.offsetLocation = m_onscreenPass.shader->uniformLocation("offset");
        m_onscreenPass.halfpixelLocation = m_onscreenPass.shader->uniformLocation("halfpixel");
        m_onscreenPass.boxLocation = m_onscreenPass.shader->uniformLocation("box");
        m_onscreenPass.cornerRadiusLocation = m_onscreenPass.shader->uniformLocation("cornerRadius");
        m_onscreenPass.opacityLocation = m_onscreenPass.shader->uniformLocation("opacity");
        m_onscreenPass.noiseLocation = m_onscreenPass.shader->uniformLocation("noise");
    }

    m_downsamplePass.shader = ShaderManager::instance()->generateShaderFromFile(ShaderTrait::MapTexture,
                                                                                shaders + QStringLiteral("vertex.vert"),
                                                                                shaders + QStringLiteral("downsample.frag"));
    if (!m_downsamplePass.shader) {
        qCWarning(AMBROSIA_GLASS) << "Failed to load downsampling pass shader";
        return;
    } else {
        m_downsamplePass.mvpMatrixLocation = m_downsamplePass.shader->uniformLocation("modelViewProjectionMatrix");
        m_downsamplePass.offsetLocation = m_downsamplePass.shader->uniformLocation("offset");
        m_downsamplePass.halfpixelLocation = m_downsamplePass.shader->uniformLocation("halfpixel");
    }

    m_upsamplePass.shader = ShaderManager::instance()->generateShaderFromFile(ShaderTrait::MapTexture,
                                                                              shaders + QStringLiteral("vertex.vert"),
                                                                              shaders + QStringLiteral("upsample.frag"));
    if (!m_upsamplePass.shader) {
        qCWarning(AMBROSIA_GLASS) << "Failed to load upsampling pass shader";
        return;
    } else {
        m_upsamplePass.mvpMatrixLocation = m_upsamplePass.shader->uniformLocation("modelViewProjectionMatrix");
        m_upsamplePass.offsetLocation = m_upsamplePass.shader->uniformLocation("offset");
        m_upsamplePass.halfpixelLocation = m_upsamplePass.shader->uniformLocation("halfpixel");
    }

    for (const Tokens::Material &material : Tokens::materials) {
        m_colorMatrices.append(saturationMatrix(material.saturation));
    }

#if KWIN_BUILD_X11
    if (effects->xcbConnection()) {
        net_wm_blur_region = effects->announceSupportProperty(s_blurAtomName, this);
    }
#endif

    waylandServer()->backgroundEffectManager()->addBlurCapability();

    connect(GlassProtocol::self(), &GlassProtocol::changed, this, [this](SurfaceInterface *surface) {
        if (EffectWindow *w = effects->findWindow(surface)) {
            updateWindow(w);
        }
    });

    connect(effects, &EffectsHandler::windowAdded, this, &GlassEffect::slotWindowAdded);
    connect(effects, &EffectsHandler::windowDeleted, this, &GlassEffect::slotWindowDeleted);
    connect(effects, &EffectsHandler::viewRemoved, this, &GlassEffect::slotViewRemoved);
#if KWIN_BUILD_X11
    connect(effects, &EffectsHandler::propertyNotify, this, &GlassEffect::slotPropertyNotify);
    connect(effects, &EffectsHandler::xcbConnectionChanged, this, [this]() {
        net_wm_blur_region = effects->announceSupportProperty(s_blurAtomName, this);
    });
#endif

    const auto stackingOrder = effects->stackingOrder();
    for (EffectWindow *window : stackingOrder) {
        slotWindowAdded(window);
    }

    m_valid = true;
    retireBlur();
    effects->addRepaintFull();
}

GlassEffect::~GlassEffect()
{
    if (m_valid) {
        waylandServer()->backgroundEffectManager()->removeBlurCapability();
    }
}

void GlassEffect::retireBlur()
{
    // KWin's blur and this one would each draw behind every pane. Ours
    // takes its place only once it is up and drawing, so a session can leave
    // KWin's switched on for the day ours can't be loaded (a KWin newer
    // than the one this was built for, shaders a card won't take).
    if (!m_valid || m_retiring || !effects->isEffectLoaded(s_blur)) {
        return;
    }
    m_retiring = true;
    // Not from inside a paint pass or the loader's own loop.
    QTimer::singleShot(0, this, [this]() {
        m_retiring = false;
        if (effects->isEffectLoaded(s_blur)) {
            effects->unloadEffect(s_blur);
            // KWin keeps "blur can be had" as one flag, which its blur
            // took down as it left: apps that ask only where it is up
            // (KDE's) would stop asking. Up again, before anyone is told.
            waylandServer()->backgroundEffectManager()->addBlurCapability();
            effects->addRepaintFull();
        }
    });
}

void GlassEffect::reconfigure(ReconfigureFlags flags)
{
    // KWin loads its blur again when it reads its settings again.
    retireBlur();
    effects->addRepaintFull();
}

void GlassEffect::updateWindow(EffectWindow *w)
{
    std::optional<RegionF> content;
    std::optional<RegionF> frame;

#if KWIN_BUILD_X11
    if (net_wm_blur_region != XCB_ATOM_NONE) {
        if (const auto x11Window = qobject_cast<X11Window *>(w->window())) {
            Xcb::Property wmBlurRegionProperty(false, x11Window->window(), net_wm_blur_region, XCB_ATOM_CARDINAL, 0, 32768);
            if (const auto cardinals = wmBlurRegionProperty.array<uint32_t>()) {
                if (cardinals->size() == 0 || cardinals->size() == 1) {
                    // It means blur background behind whole window.
                    content = RegionF();
                } else if (cardinals->size() % 4 == 0) {
                    RegionF region;
                    for (uint i = 0; i < cardinals->size();) {
                        const int x = (*cardinals)[i++];
                        const int y = (*cardinals)[i++];
                        const int w = (*cardinals)[i++];
                        const int h = (*cardinals)[i++];
                        region += Xcb::fromXNative(Rect(x, y, w, h));
                    }
                    content = region;
                }
            }
        }
    }
#endif

    SurfaceInterface *surface = w->surface();
    if (surface && !surface->blurRegion().isEmpty()) {
        content = surface->blurRegion();
    }

    if (auto internal = w->internalWindow()) {
        const auto property = internal->property("kwin_blur");
        if (property.isValid()) {
            content = property.value<RegionF>();
        }
    }

    if (w->decorationHasAlpha() && decorationSupportsBlurBehind(w)) {
        frame = decorationBlurRegion(w);
    }

    const bool paned = surface && GlassProtocol::self()->has(surface);
    if (!paned && !content.has_value() && !frame.has_value()) {
        forget(w);
        return;
    }

    WindowGlass &glass = m_windows[w];
    glass.content = content;
    glass.frame = frame;
    layOut(w, glass);
}

void GlassEffect::layOut(EffectWindow *w, WindowGlass &glass)
{
    struct Spec
    {
        RectF rect;
        RegionF shape;
        bool pane;
        RectF box;
        qreal radius;
        int material;
        qreal opacity;
    };
    QList<Spec> specs;

    SurfaceInterface *surface = w->surface();
    const RectF contents = w->contentsRect();
    // A menu of an app that only asks for a blur is as dense as ours. A
    // Wayland menu doesn't say what it is: a popup with a blur behind it is
    // taken for one.
    const int material = (w->isPopupWindow() || w->isPopupMenu() || w->isDropdownMenu() || w->isComboBox()) ? Tokens::menuMaterial : Tokens::fallbackMaterial;

    if (surface && GlassProtocol::self()->has(surface)) {
        // Panes are in the surface's coordinates: inside a frame, the contents'.
        const QPointF origin = w->decoration() ? contents.topLeft() : QPointF();
        const QList<Pane> panes = GlassProtocol::self()->panes(surface);
        for (const Pane &pane : panes) {
            const RectF box = pane.rect.translated(origin);
            const RectF rect = box & pane.clip.translated(origin) & contents;
            if (rect.isEmpty() || pane.opacity <= 0) {
                continue;
            }
            specs.append({rect, RegionF(rect), true, box, pane.radius, pane.material, pane.opacity});
        }
        if (glass.frame.has_value() && !glass.frame->isEmpty()) {
            specs.append({glass.frame->boundingRect(), *glass.frame, false, RectF(), 0, material, 1});
        }
    } else {
        const RegionF region = blurRegion(w, glass);
        if (!region.isEmpty()) {
            specs.append({region.boundingRect(), region, false, RectF(), 0, material, 1});
        }
    }

    const QPointF pos = w->pos();
    if (size_t(specs.size()) < glass.sheets.size()) {
        for (size_t i = specs.size(); i < glass.sheets.size(); ++i) {
            effects->addRepaint(glass.sheets[i].rect.translated(pos));
        }
        effects->makeOpenGLContextCurrent();
    }
    glass.sheets.resize(specs.size());

    for (int i = 0; i < specs.size(); ++i) {
        const Spec &spec = specs[i];
        Sheet &sheet = glass.sheets[i];
        const bool same = sheet.item && sheet.rect == spec.rect && sheet.shape == spec.shape && sheet.pane == spec.pane && sheet.box == spec.box
            && sheet.radius == spec.radius && sheet.material == spec.material && sheet.opacity == spec.opacity;
        if (same) {
            continue;
        }
        if (sheet.item) {
            effects->addRepaint(sheet.rect.translated(pos));
        }
        sheet.rect = spec.rect;
        sheet.shape = spec.shape;
        sheet.pane = spec.pane;
        sheet.box = spec.box;
        sheet.radius = spec.radius;
        sheet.material = spec.material;
        sheet.opacity = spec.opacity;
        if (!sheet.item) {
            sheet.item = std::make_unique<BackgroundEffectItem>(w->windowItem());
        }
        sheet.item->setPixelsToExpandRepaintsBelowOpaqueRegions(Tokens::materials[sheet.material].expand);
        sheet.item->setEffectBoundingRect(sheet.rect);
        effects->addRepaint(sheet.rect.translated(pos));
    }
}

void GlassEffect::forget(EffectWindow *w)
{
    if (auto it = m_windows.find(w); it != m_windows.end()) {
        effects->makeOpenGLContextCurrent();
        m_windows.erase(it);
    }
}

void GlassEffect::slotWindowAdded(EffectWindow *w)
{
    SurfaceInterface *surf = w->surface();

    if (surf) {
        windowBlurChangedConnections[w] = connect(surf, &SurfaceInterface::blurChanged, this, [this, w]() {
            if (w) {
                updateWindow(w);
            }
        });
    }
    if (auto internal = w->internalWindow()) {
        internal->installEventFilter(this);
    }

    setupDecorationConnections(w);
    connect(w, &EffectWindow::windowDecorationChanged, this, [this, w]() {
        setupDecorationConnections(w);
        updateWindow(w);
    });
    // A region that is "all of the window" follows the window's size.
    connect(w, &EffectWindow::windowFrameGeometryChanged, this, [this, w]() {
        if (auto it = m_windows.find(w); it != m_windows.end()) {
            layOut(w, it->second);
        }
    });

    updateWindow(w);
}

void GlassEffect::slotWindowDeleted(EffectWindow *w)
{
    forget(w);
    if (auto it = windowBlurChangedConnections.find(w); it != windowBlurChangedConnections.end()) {
        disconnect(*it);
        windowBlurChangedConnections.erase(it);
    }
}

void GlassEffect::slotViewRemoved(KWin::RenderView *view)
{
    for (auto &[window, glass] : m_windows) {
        for (Sheet &sheet : glass.sheets) {
            if (auto it = sheet.render.find(view); it != sheet.render.end()) {
                effects->makeOpenGLContextCurrent();
                sheet.render.erase(it);
            }
        }
    }
}

#if KWIN_BUILD_X11
void GlassEffect::slotPropertyNotify(EffectWindow *w, long atom)
{
    if (w && atom == net_wm_blur_region && net_wm_blur_region != XCB_ATOM_NONE) {
        updateWindow(w);
    }
}
#endif

void GlassEffect::setupDecorationConnections(EffectWindow *w)
{
    if (!w->decoration()) {
        return;
    }

    connect(w->decoration(), &KDecoration3::Decoration::blurRegionChanged, this, [this, w]() {
        updateWindow(w);
    });
}

bool GlassEffect::eventFilter(QObject *watched, QEvent *event)
{
    auto internal = qobject_cast<QWindow *>(watched);
    if (internal && event->type() == QEvent::DynamicPropertyChange) {
        QDynamicPropertyChangeEvent *pe = static_cast<QDynamicPropertyChangeEvent *>(event);
        if (pe->propertyName() == "kwin_blur") {
            if (auto w = effects->findWindow(internal)) {
                updateWindow(w);
            }
        }
    }
    return false;
}

bool GlassEffect::supported()
{
    return effects->isOpenGLCompositing();
}

bool GlassEffect::decorationSupportsBlurBehind(const EffectWindow *w) const
{
    return w->decoration() && !w->decoration()->blurRegion().isNull();
}

RegionF GlassEffect::decorationBlurRegion(const EffectWindow *w) const
{
    if (!decorationSupportsBlurBehind(w)) {
        return RegionF();
    }

    RegionF decorationRegion = RegionF(w->decoration()->rect()) - w->contentsRect();
    //! we return only blurred regions that belong to decoration region
    return decorationRegion.intersected(RegionF(w->decoration()->blurRegion()));
}

RegionF GlassEffect::blurRegion(EffectWindow *w, const WindowGlass &glass) const
{
    RegionF region;

    const std::optional<RegionF> &content = glass.content;
    const std::optional<RegionF> &frame = glass.frame;
    if (content.has_value()) {
        if (content->isEmpty()) {
            // An empty region means that the blur effect should be enabled
            // for the whole window.
            region = w->contentsRect();
        } else if (w->decoration()) {
            region = content->translated(w->contentsRect().topLeft()) & w->contentsRect();
        } else {
            region = *content & w->contentsRect();
        }
        if (frame.has_value()) {
            region += frame.value();
        }
    } else if (frame.has_value()) {
        region = frame.value();
    }

    return region;
}

void GlassEffect::prePaintScreen(ScreenPrePaintData &data)
{
    m_currentView = data.view;
    retireBlur();

    effects->prePaintScreen(data);
}

bool GlassEffect::shouldBlur(const EffectWindow *w, int mask, const WindowPaintData &data) const
{
    if (effects->activeFullScreenEffect() && !w->data(WindowForceBlurRole).toBool()) {
        return false;
    }

    if (w->isDesktop()) {
        return false;
    }

    bool scaled = !qFuzzyCompare(data.xScale(), 1.0) && !qFuzzyCompare(data.yScale(), 1.0);
    bool translated = data.xTranslation() || data.yTranslation();

    if ((scaled || (translated || (mask & PAINT_WINDOW_TRANSFORMED))) && !w->data(WindowForceBlurRole).toBool()) {
        return false;
    }

    return true;
}

bool GlassEffect::drawWindow(const RenderTarget &renderTarget, const RenderViewport &viewport, EffectWindow *w, int mask, const Region &deviceRegion, WindowPaintData &data)
{
    if (auto it = m_windows.find(w); it != m_windows.end() && shouldBlur(w, mask, data)) {
        for (Sheet &sheet : it->second.sheets) {
            drawSheet(sheet, renderTarget, viewport, w, deviceRegion, data);
        }
    }

    // Draw the window over the blurred area
    return effects->drawWindow(renderTarget, viewport, w, mask, deviceRegion, data);
}

void GlassEffect::drawSheet(Sheet &sheet, const RenderTarget &renderTarget, const RenderViewport &viewport, EffectWindow *w, const Region &deviceRegion, WindowPaintData &data)
{
    const Tokens::Material &material = Tokens::materials[sheet.material];
    const size_t iterationCount = material.iterations;
    GlassRender &renderInfo = sheet.render[m_currentView];

    // Compute the effective blur shape. Note that if the window is transformed, so will be the blur shape.
    RegionF blurShape = sheet.shape;
    if (data.xScale() != 1 || data.yScale() != 1) {
        blurShape.scale(data.xScale(), data.yScale());
    }
    if (data.xTranslation() || data.yTranslation()) {
        blurShape.translate(data.xTranslation(), data.yTranslation());
    }

    blurShape.translate(w->pos());

    // A pane may lie between pixels: its outline is drawn smooth, over
    // every pixel it touches.
    const Rect backgroundRect = sheet.pane ? blurShape.boundingRect().roundedOut() : blurShape.boundingRect().rounded();
    if (backgroundRect.isEmpty()) {
        return;
    }
    const Rect scaledBackgroundRect = backgroundRect.scaled(viewport.scale()).rounded();
    const Rect deviceBackgroundRect = viewport.mapToDeviceCoordinates(backgroundRect).rounded();
    const auto opacity = w->opacity() * data.opacity() * sheet.opacity;

    const auto toDevice = [&](const RectF &shapeRect) -> RectF {
        const RectF scaled = shapeRect.translated(-backgroundRect.topLeft()).scaled(viewport.scale());
        return sheet.pane ? RectF(scaled.roundedOut()) : RectF(scaled.rounded());
    };

    // Get the effective shape that will be actually blurred. It's possible that all of it will be clipped.
    QList<RectF> effectiveShape;
    effectiveShape.reserve(blurShape.rects().size());
    if (deviceRegion != Region::infinite()) {
        for (const Rect &clipRect : deviceRegion.rects()) {
            const RectF deviceClipRect = clipRect.translated(-deviceBackgroundRect.topLeft());
            for (const RectF &shapeRect : blurShape.rects()) {
                if (const RectF intersected = deviceClipRect.intersected(toDevice(shapeRect)); !intersected.isEmpty()) {
                    effectiveShape.append(intersected);
                }
            }
        }
    } else {
        for (const RectF &rect : blurShape.rects()) {
            effectiveShape.append(toDevice(rect));
        }
    }
    if (effectiveShape.isEmpty()) {
        return;
    }

    // Maybe reallocate offscreen render targets. Keep in mind that the first one contains
    // original background behind the window, it's not blurred.
    GLenum textureFormat = GL_RGBA8;
    if (renderTarget.texture()) {
        textureFormat = renderTarget.texture()->internalFormat();
    }

    if (renderInfo.framebuffers.size() != (iterationCount + 1) || renderInfo.textures[0]->size() != backgroundRect.size() || renderInfo.textures[0]->internalFormat() != textureFormat) {
        renderInfo.framebuffers.clear();
        renderInfo.textures.clear();

        glClearColor(0, 0, 0, 0);
        for (size_t i = 0; i <= iterationCount; ++i) {
            // A small pane halved a few times still has a pixel to blur in.
            const QSize size(std::max(1, backgroundRect.width() >> i), std::max(1, backgroundRect.height() >> i));
            auto texture = GLTexture::allocate(textureFormat, size);
            if (!texture) {
                qCWarning(AMBROSIA_GLASS) << "Failed to allocate an offscreen texture";
                renderInfo.framebuffers.clear();
                renderInfo.textures.clear();
                return;
            }
            texture->setFilter(GL_LINEAR);
            texture->setWrapMode(GL_CLAMP_TO_EDGE);

            auto framebuffer = std::make_unique<GLFramebuffer>(texture.get());
            if (!framebuffer->valid()) {
                qCWarning(AMBROSIA_GLASS) << "Failed to create an offscreen framebuffer";
                renderInfo.framebuffers.clear();
                renderInfo.textures.clear();
                return;
            }
            EglContext::currentContext()->pushFramebuffer(framebuffer.get());
            glClear(GL_COLOR_BUFFER_BIT);
            EglContext::currentContext()->popFramebuffer();
            renderInfo.textures.push_back(std::move(texture));
            renderInfo.framebuffers.push_back(std::move(framebuffer));
        }
    }

    // Fetch the pixels behind the shape that is going to be blurred.
    const Region dirtyRegion = viewport.mapFromDeviceCoordinatesContained(deviceRegion) & backgroundRect;
    for (const Rect &dirtyRect : dirtyRegion.rects()) {
        renderInfo.framebuffers[0]->blitFromRenderTarget(renderTarget, viewport, dirtyRect, dirtyRect.translated(-backgroundRect.topLeft()));
    }

    // Upload the geometry: the first 6 vertices are used when downsampling and upsampling offscreen,
    // the remaining vertices are used when rendering on the screen.
    GLVertexBuffer *vbo = GLVertexBuffer::streamingBuffer();
    vbo->reset();
    vbo->setAttribLayout(std::span(GLVertexBuffer::GLVertex2DLayout), sizeof(GLVertex2D));

    const int vertexCount = effectiveShape.size() * 6;
    if (auto result = vbo->map<GLVertex2D>(6 + vertexCount)) {
        auto map = *result;

        size_t vboIndex = 0;

        // The geometry that will be blurred offscreen, in logical pixels.
        {
            const RectF localRect = RectF(0, 0, backgroundRect.width(), backgroundRect.height());

            const float x0 = localRect.left();
            const float y0 = localRect.top();
            const float x1 = localRect.right();
            const float y1 = localRect.bottom();

            const float u0 = x0 / backgroundRect.width();
            const float v0 = 1.0f - y0 / backgroundRect.height();
            const float u1 = x1 / backgroundRect.width();
            const float v1 = 1.0f - y1 / backgroundRect.height();

            // first triangle
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x0, y0),
                .texcoord = QVector2D(u0, v0),
            };
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x1, y1),
                .texcoord = QVector2D(u1, v1),
            };
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x0, y1),
                .texcoord = QVector2D(u0, v1),
            };

            // second triangle
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x0, y0),
                .texcoord = QVector2D(u0, v0),
            };
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x1, y0),
                .texcoord = QVector2D(u1, v0),
            };
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x1, y1),
                .texcoord = QVector2D(u1, v1),
            };
        }

        // The geometry that will be painted on screen, in device pixels.
        for (const RectF &rect : effectiveShape) {
            const float x0 = rect.left();
            const float y0 = rect.top();
            const float x1 = rect.right();
            const float y1 = rect.bottom();

            const float u0 = x0 / scaledBackgroundRect.width();
            const float v0 = 1.0f - y0 / scaledBackgroundRect.height();
            const float u1 = x1 / scaledBackgroundRect.width();
            const float v1 = 1.0f - y1 / scaledBackgroundRect.height();

            // first triangle
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x0, y0),
                .texcoord = QVector2D(u0, v0),
            };
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x1, y1),
                .texcoord = QVector2D(u1, v1),
            };
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x0, y1),
                .texcoord = QVector2D(u0, v1),
            };

            // second triangle
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x0, y0),
                .texcoord = QVector2D(u0, v0),
            };
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x1, y0),
                .texcoord = QVector2D(u1, v0),
            };
            map[vboIndex++] = GLVertex2D{
                .position = QVector2D(x1, y1),
                .texcoord = QVector2D(u1, v1),
            };
        }

        vbo->unmap();
    } else {
        qCWarning(AMBROSIA_GLASS) << "Failed to map vertex buffer";
        return;
    }

    vbo->bindArrays();

    // The downsample pass of the dual Kawase algorithm: the background will be scaled down 50% every iteration.
    {
        ShaderManager::instance()->pushShader(m_downsamplePass.shader.get());

        QMatrix4x4 projectionMatrix;
        projectionMatrix.ortho(QRectF(0.0, 0.0, backgroundRect.width(), backgroundRect.height()));

        m_downsamplePass.shader->setUniform(m_downsamplePass.mvpMatrixLocation, projectionMatrix);
        m_downsamplePass.shader->setUniform(m_downsamplePass.offsetLocation, material.offset);

        for (size_t i = 1; i < renderInfo.framebuffers.size(); ++i) {
            const auto &read = renderInfo.framebuffers[i - 1];
            const auto &draw = renderInfo.framebuffers[i];

            const QVector2D halfpixel(0.5 / read->colorAttachment()->width(),
                                      0.5 / read->colorAttachment()->height());
            m_downsamplePass.shader->setUniform(m_downsamplePass.halfpixelLocation, halfpixel);

            read->colorAttachment()->bind();

            GLFramebuffer::pushFramebuffer(draw.get());
            vbo->draw(GL_TRIANGLES, 0, 6);
        }

        ShaderManager::instance()->popShader();
    }

    // The upsample pass of the dual Kawase algorithm: the background will be scaled up 200% every iteration.
    {
        ShaderManager::instance()->pushShader(m_upsamplePass.shader.get());

        QMatrix4x4 projectionMatrix;
        projectionMatrix.ortho(QRectF(0.0, 0.0, backgroundRect.width(), backgroundRect.height()));

        m_upsamplePass.shader->setUniform(m_upsamplePass.mvpMatrixLocation, projectionMatrix);
        m_upsamplePass.shader->setUniform(m_upsamplePass.offsetLocation, material.offset);

        for (size_t i = renderInfo.framebuffers.size() - 1; i > 1; --i) {
            GLFramebuffer::popFramebuffer();
            const auto &read = renderInfo.framebuffers[i];

            const QVector2D halfpixel(0.5 / read->colorAttachment()->width(),
                                      0.5 / read->colorAttachment()->height());
            m_upsamplePass.shader->setUniform(m_upsamplePass.halfpixelLocation, halfpixel);

            read->colorAttachment()->bind();

            vbo->draw(GL_TRIANGLES, 0, 6);
        }

        ShaderManager::instance()->popShader();
    }

    const float modulation = opacity * opacity;

    // The last pass: back onto the screen, inside the sheet's outline.
    {
        ShaderManager::instance()->pushShader(m_onscreenPass.shader.get());

        QMatrix4x4 projectionMatrix = viewport.projectionMatrix();
        projectionMatrix.translate(scaledBackgroundRect.x(), scaledBackgroundRect.y());

        GLFramebuffer::popFramebuffer();
        const auto &read = renderInfo.framebuffers[1];

        const QVector2D halfpixel(0.5 / read->colorAttachment()->width(),
                                  0.5 / read->colorAttachment()->height());

        // The outline, in device pixels from the background's corner:
        // a pane's own, the window's where it has rounded corners, or none
        // (a box far wider than anything drawn).
        QVector4D box(0, 0, 1.0e6, 1.0e6);
        QVector4D corners;
        if (sheet.pane) {
            const RectF outline = RectF{
                w->pos().x() + sheet.box.x() * data.xScale() + data.xTranslation(),
                w->pos().y() + sheet.box.y() * data.yScale() + data.yTranslation(),
                sheet.box.width() * data.xScale(),
                sheet.box.height() * data.yScale(),
            };
            const RectF nativeBox = outline.scaled(viewport.scale()).translated(-scaledBackgroundRect.topLeft());
            const float radius = sheet.radius * viewport.scale() * std::min(data.xScale(), data.yScale());
            box = QVector4D(nativeBox.x() + nativeBox.width() * 0.5, nativeBox.y() + nativeBox.height() * 0.5, nativeBox.width() * 0.5, nativeBox.height() * 0.5);
            corners = QVector4D(radius, radius, radius, radius);
        } else if (const BorderRadius cornerRadius = w->window()->borderRadius(); !cornerRadius.isNull()) {
            const RectF transformedRect = RectF{
                w->frameGeometry().x() + data.xTranslation(),
                w->frameGeometry().y() + data.yTranslation(),
                w->frameGeometry().width() * data.xScale(),
                w->frameGeometry().height() * data.yScale(),
            };
            const RectF nativeBox = transformedRect
                                        .scaled(viewport.scale())
                                        .rounded()
                                        .translated(-scaledBackgroundRect.topLeft());
            box = QVector4D(nativeBox.horizontalCenter(), nativeBox.verticalCenter(), nativeBox.width() * 0.5, nativeBox.height() * 0.5);
            corners = cornerRadius.scaled(viewport.scale()).rounded().toVector();
        }

        m_onscreenPass.shader->setUniform(m_onscreenPass.mvpMatrixLocation, projectionMatrix);
        m_onscreenPass.shader->setUniform(m_onscreenPass.colorMatrixLocation, m_colorMatrices[sheet.material]);
        m_onscreenPass.shader->setUniform(m_onscreenPass.halfpixelLocation, halfpixel);
        m_onscreenPass.shader->setUniform(m_onscreenPass.offsetLocation, material.offset);
        m_onscreenPass.shader->setUniform(m_onscreenPass.boxLocation, box);
        m_onscreenPass.shader->setUniform(m_onscreenPass.cornerRadiusLocation, corners);
        m_onscreenPass.shader->setUniform(m_onscreenPass.opacityLocation, modulation);
        m_onscreenPass.shader->setUniform(m_onscreenPass.noiseLocation, Tokens::noise);

        read->colorAttachment()->bind();

        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

        vbo->draw(GL_TRIANGLES, 6, vertexCount);

        glDisable(GL_BLEND);

        ShaderManager::instance()->popShader();
    }

    vbo->unbindArrays();
}

bool GlassEffect::isActive() const
{
    return m_valid && !effects->isScreenLocked();
}

bool GlassEffect::blocksDirectScanout() const
{
    return false;
}

} // namespace Ambrosia

#include "moc_glass.cpp"
