import QtQuick
import Ambrosia
import TextEditor

// The format bar of a rich text window, each control where macOS 27's
// TextEdit has it (Look.qml): bold, italic, underline and strikethrough;
// the text's color and its highlight; the font's family, style and size;
// the paragraph's alignment, list and line spacing. Each shows what holds
// where the cursor is and changes the selection (or what is typed next).
Item {
    id: bar

    required property var window
    readonly property Editor editor: window.editor
    readonly property real menuHeight: Math.max(120, window.height - Look.formatBar - 24)
    readonly property bool editing: size.editing

    function toggle(key) {
        switch (key) {
        case "bold": editor.setBold(!editor.bold); break;
        case "italic": editor.setItalic(!editor.italic); break;
        case "underline": editor.setUnderline(!editor.underline); break;
        case "strike": editor.setStrike(!editor.strike); break;
        }
    }

    Segments {
        x: 8
        y: Look.controlY
        width: 85.5
        segments: [
            { key: "bold", letter: "B", bold: true, on: bar.editor.bold },
            { key: "italic", letter: "I", italic: true, on: bar.editor.italic },
            { key: "underline", letter: "U", underline: true, on: bar.editor.underline },
            { key: "strike", letter: "S", strike: true, on: bar.editor.strike },
        ]
        onTapped: (key) => bar.toggle(key)
    }
    ColorWell {
        x: 98.5
        y: Look.controlY
        shown: bar.editor.color.valid ? bar.editor.color : Look.text
        current: bar.editor.color.valid ? String(bar.editor.color) : "#000000"
        colors: Look.textColors
        // Black is the text's own color, whatever the appearance.
        onChosen: (color) => bar.editor.setColor(color === "#000000" ? "" : color)
    }
    ColorWell {
        x: 124
        y: Look.controlY
        marker: true
        shown: bar.editor.highlight.valid ? bar.editor.highlight : "transparent"
        current: bar.editor.highlight.valid ? String(bar.editor.highlight) : ""
        colors: Look.highlights
        onChosen: (color) => bar.editor.setHighlight(color)
    }
    PopUp {
        x: 148.5
        y: Look.controlY
        width: 80
        text: bar.editor.family
        items: App.families.map(family => ({ text: family, value: family }))
        current: bar.editor.family
        menuWidth: 200
        menuHeight: bar.menuHeight
        onChosen: (family) => bar.editor.setFamily(family)
    }
    PopUp {
        id: style
        x: 233.5
        y: Look.controlY
        width: 80
        readonly property var styles: App.styles(bar.editor.family)
        // The style the cursor's weight and slant are, by the family's
        // own names; failing one, the nearest of the four.
        readonly property string now: {
            const weight = bar.editor.weight, italic = bar.editor.italic;
            const exact = styles.find(name => {
                const is = App.style(bar.editor.family, name);
                return is.weight === weight && is.italic === italic;
            });
            return exact ?? (bar.editor.bold ? (italic ? "Bold Italic" : "Bold") : italic ? "Italic" : "Regular");
        }
        text: now
        items: styles.map(name => ({ text: name, value: name }))
        current: now
        menuHeight: bar.menuHeight
        onChosen: (name) => {
            const is = App.style(bar.editor.family, name);
            bar.editor.setStyle(is.weight, is.italic);
        }
    }
    SizeField {
        id: size
        x: 318.5
        y: Look.controlY
        width: 51
        size: bar.editor.size
        menuHeight: bar.menuHeight
        onChosen: (size) => bar.editor.setSize(size)
        onDone: bar.window.takeKeys()
    }
    Segments {
        x: 373.5
        y: Look.controlY
        width: 96
        segments: [
            { key: "left", glyph: "alignLeft", on: bar.editor.alignment === "left" },
            { key: "center", glyph: "alignCenter", on: bar.editor.alignment === "center" },
            { key: "right", glyph: "alignRight", on: bar.editor.alignment === "right" },
            { key: "justify", glyph: "alignJustify", on: bar.editor.alignment === "justify" },
        ]
        onTapped: (key) => bar.editor.setAlignment(key)
    }
    PopUp {
        x: 474.5
        y: Look.controlY
        width: 46
        glyph: "list"
        chevron: "chevronDown"
        items: [
            { text: "None", value: "" }, {},
            { text: "•", value: "disc" }, { text: "◦", value: "circle" }, { text: "▪", value: "square" }, {},
            { text: "1.  2.  3.", value: "decimal" }, { text: "a.  b.  c.", value: "lower-alpha" }, { text: "A.  B.  C.", value: "upper-alpha" },
            { text: "i.  ii.  iii.", value: "lower-roman" }, { text: "I.  II.  III.", value: "upper-roman" },
        ]
        current: bar.editor.listMarker
        menuWidth: 120
        menuHeight: bar.menuHeight
        onChosen: (marker) => bar.editor.setList(marker)
    }
    PopUp {
        x: 525.5
        y: Look.controlY
        width: 51
        text: bar.editor.spacing.toFixed(Math.abs(bar.editor.spacing * 10 - Math.round(bar.editor.spacing * 10)) < 0.01 ? 1 : 2)
        items: [1, 1.2, 1.5, 2].map(spacing => ({ text: spacing.toFixed(1), value: spacing }))
        current: Math.round(bar.editor.spacing * 100) / 100
        menuWidth: 80
        menuHeight: bar.menuHeight
        onChosen: (spacing) => bar.editor.setSpacing(spacing)
    }
}
