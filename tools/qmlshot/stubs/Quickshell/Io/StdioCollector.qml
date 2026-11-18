import QtQml

QtObject {
    property string text
    property bool waitForEnd: true
    signal streamFinished()
}
