import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool dimmed: false
  property bool badge: false
  property color badgeColor: Color.urgent

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize
  opacity: dimmed ? 0.55 : 1.0

  readonly property real bodyW: iconSize * 0.52
  readonly property real bodyH: iconSize * 0.78
  readonly property real radius: iconSize * 0.12

  Rectangle {
    id: body
    width: root.bodyW
    height: root.bodyH
    radius: root.radius
    color: "transparent"
    border.color: root.color
    border.width: Math.max(1.5, root.iconSize * 0.08)
    anchors.centerIn: parent

    Rectangle {
      width: parent.width * 0.38
      height: Math.max(1.5, root.iconSize * 0.06)
      radius: height / 2
      color: root.color
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: parent.height * 0.12
    }
  }

  BorderSurface {
    visible: root.badge
    width: Math.max(7, parent.width * 0.38)
    height: width
    radius: width / 2
    color: root.badgeColor
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    borderSpec: Border.flat(Color.popups.background, 1)
  }
}
