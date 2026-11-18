#include "apps.h"

#include <KService>

namespace Ambrosia
{

QString Apps::name(const QString &desktopFile) const
{
    if (desktopFile.isEmpty()) {
        return {};
    }
    const KService::Ptr service = KService::serviceByDesktopName(desktopFile);
    return service ? service->name() : QString();
}

QString Apps::icon(const QString &desktopFile) const
{
    if (desktopFile.isEmpty()) {
        return {};
    }
    const KService::Ptr service = KService::serviceByDesktopName(desktopFile);
    return service ? service->icon() : QString();
}

}
