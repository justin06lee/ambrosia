// org.ambrosia.scrolling: a trackpad's scrolling as a Mac's (kit/scrolling.h)
// for a QML program that isn't a QApplication, so never loads the widget
// style that brings it to the others: the shell. Importing the module is
// all there is to it.
#include "../../kit/scrolling.h"

#include <QQmlExtensionPlugin>
#include <qqml.h>

class AmbrosiaScrollingQmlPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)

public:
    void registerTypes(const char *uri) override
    {
        qmlRegisterModule(uri, 1, 0);
        // (Called on the thread that loads QML: the filter belongs to the
        // application's.)
        QMetaObject::invokeMethod(qGuiApp, [] { kitScrolling(qGuiApp); }, Qt::QueuedConnection);
    }
};

#include "plugin.moc"
