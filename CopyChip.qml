import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root
  property var snippet: null
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal activated()

  implicitHeight: label.implicitHeight + Style.space(10)
  radius: Style.cornerRadius
  color: Style.hoverFillFor(foreground, Color.accent)
  borderSpec: Border.controlSpec("normal", foreground, Color.accent)

  MouseArea {
    anchors.fill: parent
    z: 2
    hoverEnabled: true
    preventStealing: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }

  Text {
    id: label
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: Style.space(6)
    textFormat: Text.PlainText
    text: "󰆏  " + String((root.snippet && root.snippet.label) || "Copy")
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideMiddle
  }
}
