import QtQuick
import Ambrosia
import Settings

// General › Language & Region: the user's languages and region, shown from the
// next login, and how dates and numbers read there; the system's locale is not
// touched. Left out: Calendar, Temperature
// and Measurement system, and setting First day, Date and Number format apart
// from the region (they follow it here), Live Text, Applications, Translation
// Languages… and the help button.
Page {
    id: page

    SectionHeading {
        first: true
        text: qsTr("Preferred Languages")
    }
    PickList {
        items: Region.languages
        canRemove: Region.languages.length > 1
        onAddRequested: chooser.open = true
        onRemoveRequested: (value) => Region.removeLanguage(value)
    }

    Item {
        width: Look.boxWidth
        height: samples.height + 16
        Column {
            id: samples
            y: 8
            width: parent.width
            spacing: 2
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                style: Theme.text.caption
                color: Theme.color.label.secondary
                text: Region.sampleLong
            }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                style: Theme.text.caption
                color: Theme.color.label.secondary
                text: Region.sampleShort + "   " + Region.sampleNumbers
            }
        }
    }

    Box {
        FormRow {
            label: qsTr("Region")
            PopUpButton {
                items: Region.regions
                current: Region.region
                onChosen: (value) => Region.setRegion(value)
            }
        }
        FormRow {
            label: qsTr("First day of week")
            value: Region.firstDay
        }
        FormRow {
            label: qsTr("Date format")
            value: Region.dateFormat
        }
        FormRow {
            label: qsTr("Number format")
            value: Region.numberFormat
        }
    }
    Label {
        x: Look.boxPadding
        width: Look.boxWidth - 2 * x
        wrapMode: Text.WordWrap
        style: Theme.text.caption
        color: Theme.color.label.secondary
        text: qsTr("Changes take effect the next time you log in.")
    }

    ChooserSheet {
        id: chooser
        settings: page.settings
        title: qsTr("Select a preferred language to add")
        items: Region.available
        onPicked: (value) => Region.addLanguage(value)
    }
}
