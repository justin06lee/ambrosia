import QtQuick
import Ambrosia
import Settings

// The theme follows the system's appearance and accent (or --appearance).
// The Settings window holds one, so the theme holds while any window is
// open; none restores the old value when its window goes.
QtObject {
    property Binding dark: Binding {
        target: Theme
        property: "dark"
        value: App.dark
        restoreMode: Binding.RestoreNone
    }
    property Binding accent: Binding {
        // The system accent, as the nearest of Ambrosia's accents.
        target: Theme
        property: "accentName"
        when: App.accent.valid
        restoreMode: Binding.RestoreNone
        value: {
            const want = App.accent;
            let best = "blue", distance = 1e9;
            for (const name of ["blue", "purple", "pink", "red", "orange", "honey", "green", "graphite"]) {
                const c = Theme.lightColors.accents[name].bg;
                const d = (c.r - want.r) ** 2 + (c.g - want.g) ** 2 + (c.b - want.b) ** 2;
                if (d < distance) { distance = d; best = name; }
            }
            return best;
        }
    }
}
