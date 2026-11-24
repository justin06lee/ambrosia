// SPDX-FileCopyrightText: 2026 Justin Lee
// SPDX-License-Identifier: MIT

#include "pane.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

// org.ambrosia.glass: how Ambrosia's QML (the shell, Files, Settings) tells
// the compositor where its panes of glass are (ambrosia_glass_v1).
class AmbrosiaGlassQmlPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<Ambrosia::GlassPane>(uri, 1, 0, "GlassPane");
    }
};

#include "plugin.moc"
