#include "decoration.h"

#include <KPluginFactory>

K_PLUGIN_FACTORY_WITH_JSON(AmbrosiaDecorationFactory, "metadata.json", registerPlugin<Ambrosia::Decoration>();)

#include "plugin.moc"
