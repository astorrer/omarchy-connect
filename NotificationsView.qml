import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
  id: root
  property var service: null
  property var device: null
  property string page: "list"
  property var current: null
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.family
  property bool cursorActive: false
  property int listIndex: 0
  property string draft: ""

  readonly property var notifications: service ? (service.notifications || []) : []
  readonly property bool loading: service ? service.smsLoading === true : false
  readonly property string deviceId: device ? String(device.id || "") : ""
  readonly property bool editorFocused: draftField.activeFocus
  readonly property bool hasDismissable: {
    for (var i = 0; i < notifications.length; i++) {
      if (notifications[i] && notifications[i].dismissable) return true
    }
    return false
  }

  signal backRequested()
  signal releaseEditor()

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  function openList() {
    page = "list"
    current = null
    draft = ""
    listIndex = 0
    cursorActive = true
    if (deviceId !== "") service.loadNotifications(deviceId)
    releaseEditor()
  }

  function openReply(item) {
    current = item
    page = "reply"
    draft = ""
    cursorActive = true
    Qt.callLater(function() { if (draftField) draftField.forceActiveFocus() })
  }

  function listMax() {
    if (notifications.length === 0) return 0
    return (hasDismissable ? 1 : 0) + notifications.length - 1
  }

  function currentItem() {
    if (page === "reply") return draftField
    if (hasDismissable && listIndex === 0) return dismissAllRow
    var offset = hasDismissable ? 1 : 0
    if (notifRepeater) return notifRepeater.itemAt(listIndex - offset)
    return backButton
  }

  function notificationAtCursor() {
    var offset = hasDismissable ? 1 : 0
    return notifications[listIndex - offset]
  }

  function moveList(dy) {
    if (dy === 0) return
    cursorActive = true
    if (page === "reply") return
    listIndex = Math.max(0, Math.min(listMax(), listIndex + dy))
  }

  function activateList() {
    if (page === "reply") {
      sendDraft()
      return
    }
    if (hasDismissable && listIndex === 0) {
      if (service) service.dismissAllNotifications(deviceId)
      return
    }
    var item = notificationAtCursor()
    if (!item) return
    if (item.canReply) openReply(item)
  }

  function dismissCurrent() {
    if (page !== "list" || !service) return
    if (hasDismissable && listIndex === 0) {
      service.dismissAllNotifications(deviceId)
      return
    }
    var item = notificationAtCursor()
    if (item && item.dismissable) service.dismissNotification(deviceId, item.id)
  }

  function sendDraft() {
    var text = String(draft || "").trim()
    if (!service || !deviceId || !current || text === "") return
    service.replyNotification(deviceId, current.id, text)
    draft = ""
    openList()
  }

  RowLayout {
    width: parent.width
    spacing: Style.space(8)

    CursorSurface {
      id: backButton
      hasCursor: false
      foreground: root.foreground
      implicitWidth: backLabel.implicitWidth + Style.space(12)
      implicitHeight: backLabel.implicitHeight + Style.space(8)
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.page === "list") root.backRequested()
          else root.openList()
        }
      }
      Text {
        id: backLabel
        anchors.centerIn: parent
        text: root.page === "list" ? "Devices" : "Inbox"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    Text {
      Layout.fillWidth: true
      text: root.page === "reply" ? Model.notificationTitle(root.current) : "Notifications"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
  }

  Text {
    visible: root.loading && root.page === "list"
    width: parent.width
    text: "Loading…"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Column {
    visible: root.page === "list"
    width: parent.width
    spacing: Style.space(6)

    CursorSurface {
      id: dismissAllRow
      visible: root.hasDismissable
      width: parent.width
      hasCursor: root.cursorActive && root.page === "list" && root.listIndex === 0
      foreground: root.foreground
      implicitHeight: Style.space(32)
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { root.cursorActive = true; root.listIndex = 0 }
        onClicked: if (root.service) root.service.dismissAllNotifications(root.deviceId)
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        text: "󰆴  Dismiss all"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    Text {
      visible: !root.loading && root.notifications.length === 0
      width: parent.width
      text: "No notifications from the phone right now."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Repeater {
      id: notifRepeater
      model: root.notifications
      CursorSurface {
        id: notifRow
        required property var modelData
        required property int index
        width: parent.width
        hasCursor: root.cursorActive && root.page === "list" && root.listIndex === index + (root.hasDismissable ? 1 : 0)
        foreground: root.foreground
        implicitHeight: notifInner.implicitHeight + Style.spacing.rowPaddingX
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: {
            root.cursorActive = true
            root.listIndex = notifRow.index + (root.hasDismissable ? 1 : 0)
          }
          onClicked: {
            root.listIndex = notifRow.index + (root.hasDismissable ? 1 : 0)
            if (notifRow.modelData && notifRow.modelData.canReply) root.openReply(notifRow.modelData)
          }
        }
        RowLayout {
          id: notifInner
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(1)
            RowLayout {
              Layout.fillWidth: true
              Text {
                textFormat: Text.PlainText
                text: Model.notificationTitle(notifRow.modelData)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
              Text {
                visible: !!(notifRow.modelData && notifRow.modelData.canReply)
                text: "Reply"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
            Text {
              textFormat: Text.PlainText
              text: Model.notificationMeta(notifRow.modelData)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
            Text {
              textFormat: Text.PlainText
              text: Model.notificationPreview(notifRow.modelData)
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }
        }
      }
    }
  }

  Column {
    visible: root.page === "reply"
    width: parent.width
    spacing: Style.space(8)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: Model.notificationPreview(root.current)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(6)
      TextField {
        id: draftField
        Layout.fillWidth: true
        foreground: root.foreground
        placeholderText: "Reply"
        text: root.draft
        onTextChanged: root.draft = text
        onAccepted: root.sendDraft()
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            event.accepted = true
            draftField.focus = false
            root.openList()
          }
        }
      }
      PanelActionButton {
        iconText: "󰒊"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: String(root.draft || "").trim() !== ""
        onClicked: root.sendDraft()
      }
    }
  }
}
