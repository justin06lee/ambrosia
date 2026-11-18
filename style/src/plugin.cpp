// Qt finds the style by this plugin: `widgetStyle=ambrosia` in kdeglobals, or
// QT_STYLE_OVERRIDE=ambrosia for one app.
#include "style.h"

#include <QStylePlugin>

class AmbrosiaStylePlugin : public QStylePlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QStyleFactoryInterface_iid FILE "ambrosia.json")

public:
    QStyle *create(const QString &key) override
    {
        return key.compare(QLatin1String("ambrosia"), Qt::CaseInsensitive) == 0 ? new Ambrosia::Style : nullptr;
    }
};

#include "plugin.moc"
