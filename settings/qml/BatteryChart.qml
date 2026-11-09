import QtQuick
import Ambrosia
import Settings

// The battery's level over the last 24 hours, as Battery's usage history
// draws it: a thin bar each quarter hour, green to the level it was at, a
// faint band where it was charging and a line under the chart with a bolt
// for each time it charged; the hours every three along the bottom, 0%, 50%
// and 100% up the right. No bar where UPower has nothing.
Item {
    id: chart

    property var samples: []   // Power.history(24)
    readonly property int bars: 96
    readonly property real plotWidth: width - 46
    readonly property real plotHeight: 90
    readonly property real pitch: plotWidth / bars
    readonly property real start: Date.now() - 24 * 3600 * 1000
    readonly property color green: Theme.color.palette.green
    // Each quarter: {level (-1 none), charging}.
    readonly property var quarters: {
        const list = [];
        for (let i = 0; i < bars; ++i)
            list.push({ level: -1, charging: false });
        for (const sample of samples) {
            const i = Math.floor((sample.time - start) / (15 * 60 * 1000));
            if (i < 0 || i >= bars)
                continue;
            list[i].level = Math.max(list[i].level, sample.level);
            list[i].charging = list[i].charging || sample.charging;
        }
        return list;
    }
    // The runs of quarters it charged in, [first, last].
    readonly property var charges: {
        const runs = [];
        for (let i = 0; i < bars; ++i) {
            if (!quarters[i].charging)
                continue;
            if (runs.length > 0 && runs[runs.length - 1][1] === i - 1)
                runs[runs.length - 1][1] = i;
            else
                runs.push([i, i]);
        }
        return runs;
    }

    implicitHeight: plotHeight + 46

    // Dotted lines at 0, 50 and 100%, and every three hours.
    Repeater {
        model: 3
        Rectangle {
            required property int index
            x: 0
            y: Math.round(chart.plotHeight * index / 2)
            width: chart.plotWidth
            height: 1
            color: Theme.color.separator
        }
    }
    Repeater {
        model: 3
        Label {
            required property int index
            x: chart.plotWidth + 8
            y: Math.round(chart.plotHeight * index / 2) - height / 2
            text: ["100%", "50%", "0%"][index]
            style: Theme.text.caption
            color: Theme.color.label.secondary
        }
    }
    Repeater {
        model: chart.charges
        Rectangle {
            required property var modelData
            x: modelData[0] * chart.pitch
            width: (modelData[1] - modelData[0] + 1) * chart.pitch
            height: chart.plotHeight
            color: Qt.alpha(chart.green, 0.22)
        }
    }
    Repeater {
        model: chart.quarters
        Rectangle {
            required property var modelData
            required property int index
            visible: modelData.level >= 0
            x: index * chart.pitch + chart.pitch * 0.2
            width: Math.max(1, chart.pitch * 0.6)
            height: Math.max(1, chart.plotHeight * modelData.level / 100)
            y: chart.plotHeight - height
            color: chart.green
        }
    }
    // Under the chart: each charge's line, broken in the middle for its bolt
    // where it's long enough to hold one.
    Repeater {
        model: chart.charges
        Item {
            id: charge
            required property var modelData
            readonly property bool bolt: width > 40
            x: modelData[0] * chart.pitch
            y: chart.plotHeight + 8
            width: (modelData[1] - modelData[0] + 1) * chart.pitch
            height: 4
            Rectangle {
                width: charge.bolt ? charge.width / 2 - 10 : charge.width
                height: parent.height
                radius: 2
                color: chart.green
            }
            Rectangle {
                visible: charge.bolt
                x: charge.width / 2 + 10
                width: charge.width / 2 - 10
                height: parent.height
                radius: 2
                color: chart.green
            }
            Glyph {
                visible: charge.bolt
                anchors.centerIn: parent
                name: "bolt"
                size: 16
                color: chart.green
            }
        }
    }
    // The hours, every three, from the next whole one 24 hours ago.
    Repeater {
        model: 8
        Item {
            required property int index
            readonly property date hour: {
                const first = new Date(chart.start);
                first.setMinutes(0, 0, 0);
                first.setHours(first.getHours() + 1);
                while (first.getHours() % 3 !== 0)
                    first.setHours(first.getHours() + 1);
                return new Date(first.getTime() + index * 3 * 3600 * 1000);
            }
            x: (hour.getTime() - chart.start) / (24 * 3600 * 1000) * chart.plotWidth
            y: 0
            Rectangle {
                width: 1
                height: chart.plotHeight + 20
                color: Theme.color.separator
            }
            Label {
                x: 3
                y: chart.plotHeight + 22
                style: Theme.text.caption
                color: Theme.color.label.secondary
                text: {
                    const h = parent.hour.getHours();
                    return h === 0 ? "12 A" : h === 12 ? "12 P" : String(h % 12);
                }
            }
        }
    }
}
