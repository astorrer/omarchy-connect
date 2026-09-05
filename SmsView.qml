import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Model.js" as Model

ColumnLayout {
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
  property real _savedY: 0
  property real _savedH: 0
  property bool _keepScroll: false
  property string copiedHint: ""

  readonly property var conversations: service ? (service.conversations || []) : []
  readonly property var messages: service ? (service.messages || []) : []
  readonly property bool loading: service ? service.smsLoading === true : false
  readonly property string deviceId: device ? String(device.id || "") : ""
  readonly property bool composing: page === "compose" || page === "thread"
  readonly property bool editorFocused: toField.activeFocus || draftField.activeFocus
  readonly property int listCount: page === "inbox" ? conversations.length + 2 : messages.length

  signal backRequested()
  signal releaseEditor()

  spacing: Style.space(10)

  function openInbox() {
    page = "inbox"
    thread = null
    listIndex = 0
    cursorActive = true
    pinToNewest = true
    if (deviceId !== "") service.loadConversations(deviceId)
    releaseEditor()
    scrollToTop()
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
    scrollToNewest()
  }

  function loadOlder() {
    if (!service || !thread || service.smsLoading) return
    if (service.smsHasMore === false) return
    pinToNewest = false
    _savedY = threadFlick.contentY
    _savedH = threadFlick.contentHeight
    _keepScroll = true
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

  function scrollToNewest() {
    Qt.callLater(function() {
      Qt.callLater(function() {
        if (root.page !== "thread") return
        threadFlick.contentY = Math.max(0, threadFlick.contentHeight - threadFlick.height)
      })
    })
  }

  function scrollToTop() {
    Qt.callLater(function() {
      Qt.callLater(function() {
        if (root.page !== "inbox") return
        threadFlick.contentY = 0
      })
    })
  }

  function copySnippet(item) {
    if (!item || !item.value || !service) return
    var hint = item.kind === "code" ? "Copied " + item.value : "Copied link"
    service.copyToClipboard(item.value, hint)
    copiedHint = hint
    copyHintTimer.restart()
  }

  function copyPrimary() {
    if (page !== "thread") return
    if (listIndex < 0 || listIndex >= messages.length) return
    copySnippet(Model.primaryCopySnippet(Model.messageCopySnippets(messages[listIndex])))
  }

  function scrollCursorIntoView() {
    var item = currentItem()
    if (!item || item === draftField || item === toField || item === backButton) return
    Qt.callLater(function() { Model.scrollFlickToItem(threadFlick, item, Style.space(8)) })
  }

  function inboxMax() {
    return 1 + conversations.length
  }

  function threadMax() {
    return messages.length
  }

  function currentItem() {
    if (page === "inbox") {
      if (listIndex === 0) return newRow
      if (listIndex === 1) return appRow
      if (convRepeater) return convRepeater.itemAt(listIndex - 2)
    }
    if (page === "thread") {
      if (listIndex < messages.length && msgRepeater) return msgRepeater.itemAt(listIndex)
      return draftField
    }
    if (page === "compose") return toField.activeFocus ? toField : draftField
    return backButton
  }

  function moveList(dx, dy) {
    cursorActive = true
    if (page === "compose") {
      if (dy > 0) draftField.forceActiveFocus()
      else if (dy < 0) toField.forceActiveFocus()
      return
    }
    if (page === "thread") {
      if (dx !== 0 || dy === 0) return
      if (dy < 0 && listIndex === 0) {
        loadOlder()
        return
      }
      var tMax = threadMax()
      listIndex = Math.max(0, Math.min(tMax, listIndex + dy))
      if (listIndex === tMax) {
        pinToNewest = true
        draftField.forceActiveFocus()
      } else {
        pinToNewest = false
        draftField.focus = false
        releaseEditor()
      }
      return
    }
    if (dx !== 0 && dy === 0) {
      if (listIndex === 0 && dx > 0) listIndex = 1
      else if (listIndex === 1 && dx < 0) listIndex = 0
      return
    }
    if (dy === 0) return
    if (listIndex <= 1) {
      if (dy > 0 && conversations.length > 0) listIndex = 2
      return
    }
    var next = listIndex + dy
    if (next < 2) listIndex = 0
    else listIndex = Math.min(inboxMax(), next)
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
      pinToNewest = true
      service.smsReply(deviceId, thread.threadId, text)
      draft = ""
      if (draftField) draftField.text = ""
      listIndex = (service.messages || []).length
      scrollToNewest()
      return
    }
    var number = String(composeTo || "").trim()
    if (number === "") return
    service.smsSend(deviceId, number, text)
    draft = ""
    if (draftField) draftField.text = ""
    openInbox()
  }

  Connections {
    target: root.service
    function onMessagesChanged() {
      if (root.page !== "thread") return
      if (root.pinToNewest) {
        root.listIndex = Math.max(root.listIndex, (root.messages || []).length)
        root.scrollToNewest()
      } else if (root._keepScroll) {
        Qt.callLater(function() {
          threadFlick.contentY = Math.max(0, root._savedY + (threadFlick.contentHeight - root._savedH))
          root._keepScroll = false
        })
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(8)

    Button {
      id: backButton
      text: root.page === "inbox" ? "Devices" : "Inbox"
      iconText: "󰁍"
      bordered: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: {
        if (root.page === "inbox") root.backRequested()
        else root.openInbox()
      }
    }

    Text {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignRight
      text: root.page === "compose" ? "New message" : (root.page === "thread" ? Model.conversationTitle(root.thread) : "Messages")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
  }

  PanelSeparator {
    Layout.fillWidth: true
    foreground: root.foreground
  }

  Text {
    visible: root.loading && root.page !== "thread"
    Layout.fillWidth: true
    text: "Loading…"
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    visible: root.copiedHint !== ""
    Layout.fillWidth: true
    text: root.copiedHint
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Timer {
    id: copyHintTimer
    interval: 1800
    repeat: false
    onTriggered: root.copiedHint = ""
  }

  Flickable {
    id: threadFlick
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: bodyColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    onContentYChanged: {
      if (root.page === "thread" && contentY < 48) root.loadOlder()
    }

    Column {
      id: bodyColumn
      width: threadFlick.width
      spacing: Style.space(6)

      Column {
        visible: root.page === "inbox"
        width: parent.width
        spacing: Style.space(6)

        Row {
          id: inboxTools
          width: parent.width
          spacing: Style.space(6)

          Button {
            id: newRow
            width: (inboxTools.width - inboxTools.spacing) / 2
            text: "New message"
            iconText: "󰍩"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            hasCursor: root.cursorActive && root.page === "inbox" && root.listIndex === 0
            onClicked: root.openCompose()
            onHovered: function(on) { if (on) { root.cursorActive = true; root.listIndex = 0 } }
          }

          Button {
            id: appRow
            width: (inboxTools.width - inboxTools.spacing) / 2
            text: "SMS app"
            iconText: "󰏌"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            hasCursor: root.cursorActive && root.page === "inbox" && root.listIndex === 1
            onClicked: if (root.service) root.service.smsApp(root.deviceId)
            onHovered: function(on) { if (on) { root.cursorActive = true; root.listIndex = 1 } }
          }
        }

        PanelSeparator {
          width: parent.width
          visible: root.conversations.length > 0 || !root.loading
          foreground: root.foreground
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
          id: convRepeater
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
          id: msgRepeater
          model: root.service ? root.service.messages : []
          CursorSurface {
            id: msgRow
            required property var modelData
            required property int index
            readonly property bool mine: !!modelData.fromMe
            readonly property real maxBubble: width * 0.82
            readonly property var atts: Model.messageAttachments(modelData)
            readonly property var snips: Model.messageCopySnippets(modelData)
            width: parent.width
            hasCursor: root.cursorActive && root.page === "thread" && root.listIndex === index && !root.editorFocused
            foreground: root.foreground
            implicitHeight: bubble.implicitHeight + Style.space(8)
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: { root.cursorActive = true; root.listIndex = msgRow.index }
              onClicked: { root.listIndex = (root.service.messages || []).length; draftField.forceActiveFocus() }
            }
            BorderSurface {
              id: bubble
              anchors.left: msgRow.mine ? undefined : parent.left
              anchors.right: msgRow.mine ? parent.right : undefined
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(msgRow.maxBubble, Math.max(bodyText.visible ? bodyText.implicitWidth : 0, timeText.implicitWidth, attachCol.visible ? attachCol.implicitWidth : 0, snipCol.visible ? snipCol.implicitWidth : 0) + Style.space(20))
              implicitHeight: bubbleCol.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: msgRow.mine
                ? Style.selectedFillFor(root.foreground, Color.accent)
                : Style.normalFillFor(root.foreground, Color.accent)
              borderSpec: msgRow.mine
                ? Border.controlSpec("selected", root.foreground, Color.accent)
                : Border.controlSpec("normal", root.foreground, Color.accent)
              Column {
                id: bubbleCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(8)
                spacing: Style.space(4)
                Column {
                  id: attachCol
                  visible: msgRow.atts.length > 0
                  width: Math.min(msgRow.maxBubble - Style.space(20), Style.space(200))
                  spacing: Style.space(4)
                  Repeater {
                    model: msgRow.atts
                    Item {
                      required property var modelData
                      width: attachCol.width
                      implicitHeight: thumb.visible ? thumb.height : chip.implicitHeight
                      Image {
                        id: thumb
                        visible: modelData.kind === "image" && !!modelData.thumb
                        source: modelData.thumb || ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                        width: parent.width
                        height: Math.min(Style.space(120), implicitHeight > 0 ? implicitHeight : Style.space(80))
                      }
                      BorderSurface {
                        id: chip
                        visible: !thumb.visible
                        width: parent.width
                        implicitHeight: chipLabel.implicitHeight + Style.space(10)
                        radius: Style.cornerRadius
                        color: Style.hoverFillFor(root.foreground, Color.accent)
                        borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                        Text {
                          id: chipLabel
                          anchors.left: parent.left
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          anchors.margins: Style.space(6)
                          textFormat: Text.PlainText
                          text: "󰈔  " + String((modelData && modelData.label) || "File")
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          elide: Text.ElideMiddle
                        }
                      }
                    }
                  }
                }
                Text {
                  id: bodyText
                  visible: Model.messageText(msgRow.modelData) !== ""
                  width: Math.min(msgRow.maxBubble - Style.space(20), implicitWidth)
                  textFormat: Text.PlainText
                  text: Model.messageText(msgRow.modelData)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  wrapMode: Text.Wrap
                  horizontalAlignment: msgRow.mine ? Text.AlignRight : Text.AlignLeft
                }
                Column {
                  id: snipCol
                  visible: msgRow.snips.length > 0
                  width: Math.min(msgRow.maxBubble - Style.space(20), Style.space(200))
                  spacing: Style.space(4)
                  Repeater {
                    model: msgRow.snips
                    CopyChip {
                      required property var modelData
                      snippet: modelData
                      width: snipCol.width
                      foreground: root.foreground
                      fontFamily: root.fontFamily
                      onActivated: {
                        root.listIndex = msgRow.index
                        root.copySnippet(modelData)
                      }
                    }
                  }
                }
                Text {
                  id: timeText
                  width: parent.width
                  textFormat: Text.PlainText
                  text: Model.formatSmsTime(msgRow.modelData.date)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  horizontalAlignment: msgRow.mine ? Text.AlignRight : Text.AlignLeft
                }
              }
            }
          }
        }
      }
    }
  }

  PanelSeparator {
    visible: root.page === "compose" || root.page === "thread"
    Layout.fillWidth: true
    foreground: root.foreground
  }

  Column {
    visible: root.page === "compose" || root.page === "thread"
    Layout.fillWidth: true
    spacing: Style.space(6)

    TextField {
      id: toField
      visible: root.page === "compose"
      width: parent.width
      foreground: root.foreground
      placeholderText: "Phone number"
      text: root.composeTo
      onTextChanged: if (text !== root.composeTo) root.composeTo = text
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
        onTextChanged: if (text !== root.draft) root.draft = text
        onAccepted: root.sendDraft()
        hasCursor: root.page === "thread" && root.listIndex === root.messages.length
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            event.accepted = true
            draftField.focus = false
            root.openInbox()
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
