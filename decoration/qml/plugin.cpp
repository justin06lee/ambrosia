#include "apps.h"
#include "blurbehind.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

// org.ambrosia.kwin: what Ambrosia's QML inside KWin (⌘Tab's switcher) needs
// and KWin's own QML doesn't offer.
class AmbrosiaKWinQmlPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterType<Ambrosia::BlurBehind>(uri, 1, 0, "BlurBehind");
        qmlRegisterSingletonType<Ambrosia::Apps>(uri, 1, 0, "Apps", [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new Ambrosia::Apps;
        });
    }
};

#include "plugin.moc"
