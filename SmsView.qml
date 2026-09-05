import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
  id: root
  property var service: null
  property var device: null
  property string page: "inbox"
  property var thread: null
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.family
  property bool cursorActive: false
  property int listIndex: 0
  property string draft: ""
  property string composeTo: ""
  property bool pinToNewest: true

  readonly property var conversations: service ? (service.conversations || []) : []
  readonly property var messages: service ? (service.messages || []) : []
  readonly property bool loading: service ? service.smsLoading === true : false
  readonly property string deviceId: device ? String(device.id || "") : ""
  readonly property bool composing: page === "compose" || page === "thread"
  readonly property bool editorFocused: toField.activeFocus || draftField.activeFocus
  readonly property int listCount: page === "inbox" ? conversations.length + 2 : messages.length

  signal backRequested()
  signal releaseEditor()
  signal scrollToEnd()
  signal preserveScroll()

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  function openInbox() {
    page = "inbox"
    thread = null
    listIndex = 0
    cursorActive = true
    if (deviceId !== "") service.loadConversations(deviceId)
    releaseEditor()
  }

  function openThread(conversation) {
    thread = conversation
    page = "thread"
    draft = ""
    cursorActive = true
    pinToNewest = true
    if (deviceId !== "" && conversation) service.loadThread(deviceId, conversation.threadId, conversation)
    listIndex = Math.max(0, (service.messages || []).length)
    releaseEditor()
    scrollToEnd()
  }

  function loadOlder() {
    if (!service || !thread || service.smsLoading) return
    if (service.smsHasMore === false) return
    pinToNewest = false
    preserveScroll()
    service.loadOlder(deviceId, thread.threadId)
  }

  function openCompose() {
    page = "compose"
    thread = null
    composeTo = ""
    draft = ""
    cursorActive = true
    listIndex = 0
    Qt.callLater(function() { if (toField) toField.forceActiveFocus() })
  }

  function inboxMax() {
    return 1 + conversations.length
  }

  function threadMax() {
    return messages.length
  }

  function moveList(dy) {
    if (dy === 0) return
    cursorActive = true
    if (page === "compose") {
      if (dy > 0) draftField.forceActiveFocus()
      else toField.forceActiveFocus()
      return
    }
    if (page === "thread") {
      if (dy < 0 && listIndex === 0) {
        loadOlder()
        return
      }
      var tMax = threadMax()
      listIndex = Math.max(0, Math.min(tMax, listIndex + dy))
      if (listIndex === tMax) draftField.forceActiveFocus()
      else {
        draftField.focus = false
        releaseEditor()
      }
      return
    }
    listIndex = Math.max(0, Math.min(inboxMax(), listIndex + dy))
  }

  function activateList() {
    if (page === "compose") {
      if (toField.activeFocus) {
        draftField.forceActiveFocus()
        return
      }
      sendDraft()
      return
    }
    if (page === "thread") {
      if (listIndex >= messages.length) {
        if (draftField.activeFocus) sendDraft()
        else draftField.forceActiveFocus()
      }
      return
    }
    if (listIndex === 0) {
      openCompose()
      return
    }
    if (listIndex === 1) {
      if (service) service.smsApp(deviceId)
      return
    }
    var conv = conversations[listIndex - 2]
    if (conv) openThread(conv)
  }

  function sendDraft() {
    var text = String(draft || "").trim()
    if (!service || !deviceId || text === "") return
    if (page === "thread" && thread) {
      service.smsReply(deviceId, thread.threadId, text)
      draft = ""
      Qt.callLater(function() { if (root.thread) service.loadThread(deviceId, root.thread.threadId) })
      return
    }
    var number = String(composeTo || "").trim()
    if (number === "") return
    service.smsSend(deviceId, number, text)
    draft = ""
    openInbox()
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
          if (root.page === "inbox") root.backRequested()
          else root.openInbox()
        }
      }
      Text {
        id: backLabel
        anchors.centerIn: parent
        text: root.page === "inbox" ? "Devices" : "Inbox"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    Text {
      Layout.fillWidth: true
      text: root.page === "compose" ? "New message" : (root.page === "thread" ? Model.conversationTitle(root.thread) : "Messages")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
  }

  Text {
    visible: root.loading
    width: parent.width
    text: "Loading…"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Column {
    visible: root.page === "inbox"
    width: parent.width
    spacing: Style.space(6)

    CursorSurface {
      id: newRow
      width: parent.width
      hasCursor: root.cursorActive && root.page === "inbox" && root.listIndex === 0
      foreground: root.foreground
      implicitHeight: Style.space(32)
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { root.cursorActive = true; root.listIndex = 0 }
        onClicked: root.openCompose()
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        text: "󰍩  New message"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    CursorSurface {
      width: parent.width
      hasCursor: root.cursorActive && root.page === "inbox" && root.listIndex === 1
      foreground: root.foreground
      implicitHeight: Style.space(32)
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { root.cursorActive = true; root.listIndex = 1 }
        onClicked: if (root.service) root.service.smsApp(root.deviceId)
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        text: "󰏌  Open SMS app"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    Text {
      visible: !root.loading && root.conversations.length === 0
      width: parent.width
      text: "No conversations yet. SMS needs to be enabled in KDE Connect on the phone."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Repeater {
      model: root.conversations
      CursorSurface {
        id: convRow
        required property var modelData
        required property int index
        width: parent.width
        hasCursor: root.cursorActive && root.page === "inbox" && root.listIndex === index + 2
        foreground: root.foreground
        implicitHeight: convInner.implicitHeight + Style.spacing.rowPaddingX
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: { root.cursorActive = true; root.listIndex = convRow.index + 2 }
          onClicked: root.openThread(convRow.modelData)
        }
        RowLayout {
          id: convInner
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
                text: Model.conversationTitle(convRow.modelData)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
              Text {
                text: Model.formatSmsTime(convRow.modelData.date)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
            Text {
              textFormat: Text.PlainText
              text: Model.previewText(convRow.modelData)
              color: convRow.modelData.read === 0 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }
        }
      }
    }
  }

  Column {
    visible: root.page === "thread"
    width: parent.width
    spacing: Style.space(6)

    Text {
      visible: root.service && root.service.smsHasMore !== false
      width: parent.width
      text: root.loading ? "Loading older…" : "Scroll up for older messages"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      MouseArea {
        anchors.fill: parent
        enabled: !root.loading
        cursorShape: Qt.PointingHandCursor
        onClicked: root.loadOlder()
      }
    }

    Text {
      visible: !root.loading && root.messages.length === 0
      width: parent.width
      text: "No messages in this thread."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Repeater {
      model: root.service ? root.service.messages : []
      CursorSurface {
        id: msgRow
        required property var modelData
        required property int index
        width: parent.width
        hasCursor: root.cursorActive && root.page === "thread" && root.listIndex === index && !root.editorFocused
        foreground: root.foreground
        implicitHeight: msgInner.implicitHeight + Style.space(8)
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: { root.cursorActive = true; root.listIndex = msgRow.index }
          onClicked: { root.listIndex = (root.service.messages || []).length; draftField.forceActiveFocus() }
        }
        Column {
          id: msgInner
          anchors.left: msgRow.modelData.fromMe ? undefined : parent.left
          anchors.right: msgRow.modelData.fromMe ? parent.right : undefined
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          width: parent.width * 0.82
          spacing: Style.space(2)
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: Model.messageText(msgRow.modelData)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
            horizontalAlignment: msgRow.modelData.fromMe ? Text.AlignRight : Text.AlignLeft
          }
          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: Model.formatSmsTime(msgRow.modelData.date)
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: msgRow.modelData.fromMe ? Text.AlignRight : Text.AlignLeft
          }
        }
      }
    }
  }

  Column {
    visible: root.page === "compose" || root.page === "thread"
    width: parent.width
    spacing: Style.space(6)

    TextField {
      id: toField
      visible: root.page === "compose"
      width: parent.width
      foreground: root.foreground
      placeholderText: "Phone number"
      text: root.composeTo
      onTextChanged: root.composeTo = text
      onAccepted: draftField.forceActiveFocus()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          event.accepted = true
          root.openInbox()
        } else if (event.key === Qt.Key_Down) {
          event.accepted = true
          draftField.forceActiveFocus()
        }
      }
    }

    RowLayout {
      width: parent.width
      spacing: Style.space(6)
      TextField {
        id: draftField
        Layout.fillWidth: true
        foreground: root.foreground
        placeholderText: "Message"
        text: root.draft
        onTextChanged: root.draft = text
        onAccepted: root.sendDraft()
        hasCursor: root.page === "thread" && root.listIndex === root.messages.length
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            event.accepted = true
            draftField.focus = false
            root.releaseEditor()
            if (root.page === "compose") root.openInbox()
          } else if (event.key === Qt.Key_Up && root.page === "thread") {
            event.accepted = true
            draftField.focus = false
            root.listIndex = Math.max(0, root.messages.length - 1)
            root.releaseEditor()
          } else if (event.key === Qt.Key_Up && root.page === "compose") {
            event.accepted = true
            toField.forceActiveFocus()
          }
        }
      }
      PanelActionButton {
        iconText: "󰒊"
        foreground: root.foreground
        fontFamily: root.fontFamily
        enabled: String(root.draft || "").trim() !== "" && (root.page === "thread" || String(root.composeTo || "").trim() !== "")
        onClicked: root.sendDraft()
      }
    }
  }
}
