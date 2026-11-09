#pragma once

#include <tokens.h>

#include <KDecoration3/DecorationShadow>

#include <memory>

namespace Ambrosia {

// The window shadow, painted as the preview's box-shadows are: each layer a
// blurred rounded rect, kept outside the window. One per mode and focus,
// shared by every window.
std::shared_ptr<KDecoration3::DecorationShadow> windowShadow(bool dark, bool active);

} // namespace Ambrosia
