#pragma once

#include <QStringList>
#include <QVariant>

// KWin's input devices of one kind (its InputDevice objects on the session
// bus, which apply a change at once and keep it in kcminputrc), read from
// the first that has a setting and all set alike, as the Mac sets its own.
class KWinInput
{
public:
    enum Kind { Mice, Touchpads };
    explicit KWinInput(Kind kind) : m_kind(kind) {}

    // Looks the devices up again (one may have been plugged in).
    void read();
    bool isEmpty() const { return m_devices.isEmpty(); }
    // The first device's value; with `supports`, the first device whose
    // property of that name is true (a pad without tapping has no tapToClick).
    QVariant first(const char *name, const char *supports = nullptr) const;
    // True if any device's property of that name is true.
    bool any(const char *name) const;
    void setAll(const char *name, const QVariant &value);

private:
    Kind m_kind;
    QStringList m_devices;
};
