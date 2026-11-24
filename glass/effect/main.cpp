/*
    SPDX-FileCopyrightText: 2021 Vlad Zahorodnii <vlad.zahorodnii@kde.org>
    SPDX-FileCopyrightText: 2026 Justin Lee

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include "glass.h"

namespace Ambrosia
{

// Off unless a session's kwinrc asks for it ([Plugins] ambrosia_glassEnabled).
KWIN_EFFECT_FACTORY_SUPPORTED_ENABLED(GlassEffect,
                                      "metadata.json",
                                      return GlassEffect::supported();
                                      ,
                                      return false;)

} // namespace Ambrosia

#include "main.moc"
