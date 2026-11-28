// Fingers put down on a trackpad and kept still: on a Mac that stops a
// list that is gliding. Wayland says so by the pointer-gestures
// protocol's hold gesture (zwp_pointer_gesture_hold_v1, which libinput
// makes and KWin hands to the app under the pointer), and Qt passes none
// of it on, so this listens for it itself, on Qt's own connection:
//
//     KitHold::listen([](int fingers) { ... });   // once an app, any time
//     KitHold::look();                            // now and then: see below
//
// Nothing to generate, build or link: the protocol's two interfaces are
// written out here by hand (four requests and two events between them),
// and libwayland-client, which Qt's Wayland platform has loaded already,
// is asked for its functions by name. Off Wayland, without the library,
// or under a compositor without the protocol at version 3, nothing is
// heard.
//
// The gesture belongs to a wl_pointer, which Qt has only once the seat
// has said it has one and makes anew when a pointing device comes or
// goes: look() takes the gesture for whichever pointer Qt has now, and
// costs a comparison when that hasn't changed. Call it as a scroll
// begins.
#pragma once

#include <QGuiApplication>
#include <QLibrary>
#include <QTimer>

#include <cstdint>
#include <cstring>
#include <functional>

class KitHold
{
public:
    static void listen(std::function<void(int fingers)> held)
    {
        State &s = state();
        s.held = std::move(held);
        if (s.asked)
            return;
        s.asked = true;
#if defined(Q_OS_LINUX) && QT_CONFIG(wayland)
        if (QGuiApplication::platformName() != QLatin1String("wayland"))
            return;
        auto *wayland = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
        if (!wayland || !wayland->display())
            return;
        QLibrary library(QStringLiteral("wayland-client"), 0);
        s.marshal = reinterpret_cast<Marshal>(library.resolve("wl_proxy_marshal_flags"));
        s.addListener = reinterpret_cast<AddListener>(library.resolve("wl_proxy_add_listener"));
        s.version = reinterpret_cast<Version>(library.resolve("wl_proxy_get_version"));
        const auto *registryInterface = reinterpret_cast<const Interface *>(library.resolve("wl_registry_interface"));
        if (!s.marshal || !s.addListener || !s.version || !registryInterface)
            return;
        void *display = wayland->display();
        // wl_display.get_registry (request 1); the globals come as Qt
        // next reads the connection.
        s.registry = s.marshal(display, 1, registryInterface, s.version(display), 0, nullptr);
        if (s.registry)
            s.addListener(s.registry, reinterpret_cast<void (**)(void)>(const_cast<RegistryListener *>(&registryListener())), nullptr);
#endif
    }

    static void look()
    {
#if defined(Q_OS_LINUX) && QT_CONFIG(wayland)
        State &s = state();
        if (!s.gestures)
            return;
        auto *wayland = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
        void *pointer = wayland ? wayland->pointer() : nullptr;
        if (pointer == s.pointer)
            return;
        // Destroy (request 0, the proxy with it), then one for the new
        // pointer: zwp_pointer_gestures_v1.get_hold_gesture (request 3).
        if (s.hold)
            s.marshal(s.hold, 0, nullptr, 3, 1);
        s.hold = nullptr;
        s.pointer = pointer;
        if (!pointer)
            return;
        s.hold = s.marshal(s.gestures, 3, &holdInterface(), 3, 0, nullptr, pointer);
        if (s.hold)
            s.addListener(s.hold, reinterpret_cast<void (**)(void)>(const_cast<HoldListener *>(&holdListener())), nullptr);
#endif
    }

private:
    // libwayland's wl_message and wl_interface, as its ABI has them.
    struct Interface;
    struct Message {
        const char *name;
        const char *signature;
        const Interface **types;
    };
    struct Interface {
        const char *name;
        int version;
        int requestCount;
        const Message *requests;
        int eventCount;
        const Message *events;
    };
    using Marshal = void *(*)(void *proxy, uint32_t request, const Interface *made, uint32_t version, uint32_t flags, ...);
    using AddListener = int (*)(void *proxy, void (**listener)(void), void *data);
    using Version = uint32_t (*)(void *proxy);

    struct State {
        std::function<void(int)> held;
        bool asked = false;
        Marshal marshal = nullptr;
        AddListener addListener = nullptr;
        Version version = nullptr;
        void *registry = nullptr;
        void *gestures = nullptr;
        void *hold = nullptr;
        void *pointer = nullptr;
    };
    static State &state()
    {
        static State s;
        return s;
    }

    // zwp_pointer_gesture_hold_v1: destroy; begin(serial, time, surface,
    // fingers) and end(serial, time, cancelled). An argument's type is
    // left unnamed (null) where libwayland needs none.
    static const Interface &holdInterface()
    {
        static const Interface *none[4] = {nullptr, nullptr, nullptr, nullptr};
        static const Message requests[] = {{"destroy", "3", none}};
        static const Message events[] = {{"begin", "3uuou", none}, {"end", "3uui", none}};
        static const Interface interface = {"zwp_pointer_gesture_hold_v1", 3, 1, requests, 2, events};
        return interface;
    }
    // zwp_pointer_gestures_v1: get_swipe_gesture, get_pinch_gesture,
    // release, get_hold_gesture. Only the last is ever asked for; the
    // first two are named for the count's sake.
    static const Interface &gesturesInterface()
    {
        static const Interface swipe = {"zwp_pointer_gesture_swipe_v1", 2, 0, nullptr, 0, nullptr};
        static const Interface pinch = {"zwp_pointer_gesture_pinch_v1", 2, 0, nullptr, 0, nullptr};
        static const Interface *swipeTypes[2] = {&swipe, nullptr};
        static const Interface *pinchTypes[2] = {&pinch, nullptr};
        static const Interface *holdTypes[2] = {&holdInterface(), nullptr};
        static const Interface *none[1] = {nullptr};
        static const Message requests[] = {
            {"get_swipe_gesture", "no", swipeTypes},
            {"get_pinch_gesture", "no", pinchTypes},
            {"release", "2", none},
            {"get_hold_gesture", "3no", holdTypes},
        };
        static const Interface interface = {"zwp_pointer_gestures_v1", 3, 4, requests, 0, nullptr};
        return interface;
    }

    struct RegistryListener {
        void (*global)(void *data, void *registry, uint32_t name, const char *interface, uint32_t version);
        void (*globalRemove)(void *data, void *registry, uint32_t name);
    };
    static const RegistryListener &registryListener()
    {
        static const RegistryListener listener = {
            [](void *, void *registry, uint32_t name, const char *interface, uint32_t version) {
                State &s = state();
                if (s.gestures || version < 3 || std::strcmp(interface, "zwp_pointer_gestures_v1") != 0)
                    return;
                // wl_registry.bind (request 0): name, interface, version, new id.
                s.gestures = s.marshal(registry, 0, &gesturesInterface(), 3, 0, name, gesturesInterface().name, 3, nullptr);
                // Not from inside libwayland's reading of the connection.
                QTimer::singleShot(0, qGuiApp, [] { KitHold::look(); });
            },
            [](void *, void *, uint32_t) {},
        };
        return listener;
    }

    struct HoldListener {
        void (*begin)(void *data, void *hold, uint32_t serial, uint32_t time, void *surface, uint32_t fingers);
        void (*end)(void *data, void *hold, uint32_t serial, uint32_t time, int32_t cancelled);
    };
    static const HoldListener &holdListener()
    {
        static const HoldListener listener = {
            [](void *, void *, uint32_t, uint32_t, void *, uint32_t fingers) {
                if (state().held)
                    state().held(int(fingers));
            },
            [](void *, void *, uint32_t, uint32_t, int32_t) {},
        };
        return listener;
    }
};
