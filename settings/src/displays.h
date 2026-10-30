#pragma once

#include <KScreen/Types>
#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

// Displays, on KScreen (KWin's output configuration) and PowerDevil's
// brightness service: each display in use, its scale shown as System
// Settings' "Larger Text … More Space" choices, its refresh rate,
// rotation and color profile, and its brightness where it can be dimmed.
// Changes apply at once, through KWin, as on a Mac.
class Displays : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{id, name, builtIn, scale, scales [{scale, width, height}] (most
    // room last), defaultScale, rate (the mode's id), rates [{id, text}],
    // rotation ("0", "90", "180", "270"), profile, profiles [{id, name}],
    // dimmable, brightness (0 to 1)}]: the main display first.
    Q_PROPERTY(QVariantList list READ list NOTIFY changed)
    // Scales as a list of sizes rather than tiles (Advanced…), kept in
    // ambrosiarc.
    Q_PROPERTY(bool showAsList READ showAsList WRITE setShowAsList NOTIFY showAsListChanged)

public:
    explicit Displays(QObject *parent = nullptr);

    QVariantList list() const { return m_list; }
    bool showAsList() const { return m_showAsList; }
    void setShowAsList(bool on);

    Q_INVOKABLE void setScale(int id, double scale);
    Q_INVOKABLE void setRate(int id, const QString &modeId);
    Q_INVOKABLE void setRotation(int id, const QString &rotation);
    // "srgb", "edid" (the display's own) or an ICC file's path.
    Q_INVOKABLE void setProfile(int id, const QString &profile);
    Q_INVOKABLE void setBrightness(int id, double value);

Q_SIGNALS:
    void changed();
    void showAsListChanged();

private Q_SLOTS:
    void readBrightness();

private:
    void refresh();
    void apply();
    KScreen::OutputPtr output(int id) const;

    KScreen::ConfigPtr m_config;
    QVariantList m_list;
    bool m_showAsList = false;
    // The brightness service's displays, by output id: {path, max, value}.
    QHash<int, QVariantMap> m_brightness;
};
