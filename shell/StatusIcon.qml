import QtQuick
import QtQuick.Window
import Ambrosia

// An app's own status icon, in the menu bar. Most are a one-color glyph drawn
// for some panel's light or dark, which is not ours to know: an icon that is
// mostly gray is drawn as its shape alone in the menu bar's own text color,
// as a Mac draws a template image. An icon in color is left as its app drew
// it.
Item {
    id: icon

    property string source
    property real size: Theme.size.menubar.icon
    property color color: Theme.color.label.primary
    // Whether the icon was taken for a glyph (decided once it has loaded).
    property bool glyph: false

    implicitWidth: size
    implicitHeight: size

    onSourceChanged: {
        glyph = false;
        if (source !== "") canvas.loadImage(source);
        canvas.requestPaint();
    }
    onColorChanged: canvas.requestPaint()

    // Asked for at three times the size, so it is sharp on any screen.
    Image {
        id: picture
        anchors.fill: parent
        visible: !icon.glyph
        source: icon.source
        sourceSize: Qt.size(3 * icon.size, 3 * icon.size)
        fillMode: Image.PreserveAspectFit
    }

    // The canvas looks at the icon's pixels to tell a glyph from a picture,
    // and draws the glyph: the icon's shape, filled with the color. It loads
    // the icon itself: drawn from the Image above, what it reads back is a
    // frame behind.
    Canvas {
        id: canvas

        anchors.fill: parent
        onImageLoaded: requestPaint()
        Component.onCompleted: if (icon.source !== "") loadImage(icon.source)

        onPaint: {
            const ctx = getContext("2d");
            const side = icon.size;
            ctx.globalCompositeOperation = "source-over";
            ctx.clearRect(0, 0, side, side);
            if (icon.source === "" || !isImageLoaded(icon.source)) return;
            ctx.drawImage(icon.source, 0, 0, side, side);
            // Pixels are read as the screen has them, not in our units.
            const reach = Math.ceil(side * Screen.devicePixelRatio);
            const data = ctx.getImageData(0, 0, reach, reach).data;
            let seen = 0, inColor = 0;
            for (let at = 0; at < data.length; at += 4) {
                if (data[at + 3] < 32) continue;
                seen++;
                // A pixel has color when its channels are well apart.
                const max = Math.max(data[at], data[at + 1], data[at + 2]);
                if (max > 40 && (max - Math.min(data[at], data[at + 1], data[at + 2])) / max > 0.25) inColor++;
            }
            // A thin glyph with a dot of color is still a glyph: under half.
            icon.glyph = seen > 0 && inColor / seen < 0.5;
            if (icon.glyph) {
                ctx.globalCompositeOperation = "source-in";
                ctx.fillStyle = icon.color;
                ctx.fillRect(0, 0, side, side);
            } else {
                ctx.clearRect(0, 0, side, side);
            }
        }
    }
}
