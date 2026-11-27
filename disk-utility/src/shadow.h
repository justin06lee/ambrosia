#pragma once

#include <QtGlobal>

class KWindowShadow;
class QQuickWindow;

// The shadow KWin draws round the window (owned by the window). Ask it to
// create() once the window shows.
KWindowShadow *makeShadow(QQuickWindow *window, int radius, qreal dpr);
