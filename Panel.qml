import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.astorrer.connect"
  ipcTarget: "io.github.astorrer.connect"
  manageIpc: false

  readonly property bool hideWhenDisconnected: !!setting("hideWhenDisconnected", false)
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property var primary: connect.primary
  readonly property bool phoneLive: !!(primary && primary.paired && primary.reachable)
  readonly property color barIconColor: phoneLive ? (bar ? bar.foreground : foreground) : dim
  readonly property bool headerHasCursor: cursorActive && focusSection === "header" && connect.installed
  readonly property string toggleHint: connect.active ? "Stop Connect" : "Start Connect"
  readonly property var selectedDevice: {
    if (connect.devices.length === 0) return null
    return connect.devices[Math.max(0, Math.min(deviceIndex, connect.devices.length - 1))]
  }
  readonly property var actions: Model.actionRows(selectedDevice)

  property int phraseIndex: 0
  readonly property var activePhrases: [
    "Listening for phones",
    "Pairing pockets",
    "Herding handsets",
    "Bridging pockets",
    "Finding friends",
    "Sharing quietly"
  ]
  readonly property string heroPhraseText: {
    if (!connect.installed) return "Not installed"
    if (!connect.active) return "Turned off"
    if (phoneLive) return activePhrases[phraseIndex % activePhrases.length]
    if (connect.devices.length > 0) return "Waiting to pair"
    return "No devices yet"
  }

  property string view: "main"
  property var smsDevice: null
  property string focusSection: "header"
  property int deviceIndex: 0
  property int actionIndex: 0
  property bool cursorActive: false
  property real _savedY: 0
  property real _savedH: 0
  property bool _keepScroll: false

  function pinThreadBottom() {
    Qt.callLater(function() {
      Qt.callLater(function() {
        panelFlick.contentY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      })
    })
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  visible: !hideWhenDisconnected || phoneLive || !connect.installed || connect.devices.length > 0

  function ensureCursor() {
    if (!connect.installed) {
      focusSection = "setup"
      return
    }
    if (focusSection === "devices" && connect.devices.length === 0) focusSection = "header"
    if (focusSection === "actions" && actions.length === 0) focusSection = connect.devices.length ? "devices" : "header"
    if (deviceIndex >= connect.devices.length) deviceIndex = Math.max(0, connect.devices.length - 1)
    if (actionIndex >= actions.length) actionIndex = Math.max(0, actions.length - 1)
  }

  function armCursor() {
    cursorActive = true
    if (!connect.installed) {
      focusSection = "setup"
      return
    }
    if (connect.devices.length > 0) {
      focusSection = "devices"
      if (deviceIndex < 0 || deviceIndex >= connect.devices.length) deviceIndex = 0
      return
    }
    focusSection = "header"
  }

  function goBack() {
    if (view === "sms") {
      if (smsView.page !== "inbox") smsView.openInbox()
      else {
        view = "main"
        smsDevice = null
        armCursor()
        Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
      }
      return
    }
    if (view === "notifications") {
      if (notifyView.page !== "list") notifyView.openList()
      else {
        view = "main"
        smsDevice = null
        armCursor()
        Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
      }
      return
    }
    close()
  }

  function scrollItemIntoView(item) {
    if (!panelFlick || !item) return
    Qt.callLater(function() {
      if (!panelFlick || !item) return
      var margin = Style.space(8)
      var point = item.mapToItem(panelFlick.contentItem, 0, 0)
      var top = point.y
      var bottom = top + Math.max(item.height, item.implicitHeight)
      var viewTop = panelFlick.contentY
      var viewBottom = viewTop + panelFlick.height
      var maxY = Math.max(0, panelFlick.contentHeight - panelFlick.height)
      if (top < viewTop + margin) panelFlick.contentY = Math.max(0, top - margin)
      else if (bottom > viewBottom - margin) panelFlick.contentY = Math.min(maxY, bottom + margin - panelFlick.height)
    })
  }

  function currentItem() {
    if (view === "sms") return smsView.currentItem()
    if (view === "notifications") return notifyView.currentItem()
    if (focusSection === "setup") return setupButton
    if (focusSection === "header") return header
    if (focusSection === "devices" && deviceRepeater) return deviceRepeater.itemAt(deviceIndex)
    if (focusSection === "actions" && actionRepeater) return actionRepeater.itemAt(actionIndex)
    return null
  }

  function scrollCursorIntoView() {
    if (view === "sms" && smsView.page === "thread" && smsView.pinToNewest && smsView.listIndex >= (connect.messages || []).length)
      return
    scrollItemIntoView(currentItem())
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    if (dx !== 0 && dy === 0) {
      if (dx > 0) activateCursor()
      else goBack()
      return
    }
    if (view === "sms") {
      smsView.cursorActive = true
      smsView.moveList(dy)
      scrollCursorIntoView()
      return
    }
    if (view === "notifications") {
      notifyView.cursorActive = true
      notifyView.moveList(dy)
      scrollCursorIntoView()
      return
    }
    ensureCursor()
    if (dy === 0) return
    if (focusSection === "setup") return
    if (focusSection === "header") {
      if (dy > 0 && connect.devices.length > 0) focusSection = "devices"
    } else if (focusSection === "devices") {
      if (dy < 0 && deviceIndex === 0) {
        focusSection = "header"
      } else if (dy > 0 && deviceIndex === connect.devices.length - 1 && actions.length > 0) {
        focusSection = "actions"
        actionIndex = 0
      } else {
        deviceIndex = Math.max(0, Math.min(connect.devices.length - 1, deviceIndex + dy))
      }
    } else if (focusSection === "actions") {
      if (dy < 0 && actionIndex === 0) {
        focusSection = "devices"
      } else {
        actionIndex = Math.max(0, Math.min(actions.length - 1, actionIndex + dy))
      }
    }
    scrollCursorIntoView()
  }

  function activateCursor() {
    if (view === "sms") {
      smsView.activateList()
      return
    }
    if (view === "notifications") {
      notifyView.activateList()
      return
    }
    ensureCursor()
    if (focusSection === "setup") {
      connect.setup()
      return
    }
    if (focusSection === "header") {
      connect.toggleRunning()
      return
    }
    if (focusSection === "devices") {
      runAction({ id: "messages" })
      return
    }
    if (focusSection === "actions") runAction(actions[actionIndex])
  }

  function runAction(action) {
    if (!action || !selectedDevice) return
    var id = selectedDevice.id
    if (action.id === "messages") {
      smsDevice = selectedDevice
      view = "sms"
      smsView.openInbox()
      return
    }
    if (action.id === "notifications") {
      smsDevice = selectedDevice
      view = "notifications"
      notifyView.openList()
      return
    }
    else if (action.id === "ping") connect.ping(id)
    else if (action.id === "ring") connect.ring(id)
    else if (action.id === "clipboard") connect.sendClipboard(id)
    else if (action.id === "file") connect.shareFile(id)
    else if (action.id === "pair") connect.pair(id)
    else if (action.id === "unpair") connect.unpair(id)
    else if (action.id === "accept") connect.accept(id)
    else if (action.id === "reject") connect.reject(id)
  }

  function setDeviceCursor(index) {
    cursorActive = true
    focusSection = "devices"
    deviceIndex = index
  }

  function setActionCursor(index) {
    cursorActive = true
    focusSection = "actions"
    actionIndex = index
  }

  onOpenedChanged: if (opened) {
    view = "main"
    smsDevice = null
    armCursor()
    connect.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service {
    id: connect
    settings: root.settings
  }

  Connections {
    target: connect
    function onMessagesChanged() {
      if (root.view !== "sms" || smsView.page !== "thread") return
      if (smsView.pinToNewest) {
        smsView.listIndex = Math.max(smsView.listIndex, (connect.messages || []).length)
        root.pinThreadBottom()
      } else if (root._keepScroll) {
        Qt.callLater(function() {
          panelFlick.contentY = Math.max(0, root._savedY + (panelFlick.contentHeight - root._savedH))
          root._keepScroll = false
        })
      }
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { connect.refresh(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        ConnectIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barIconColor
          dimmed: !root.phoneLive
          badge: !!(root.primary && (root.primary.pairRequestedByPeer || root.primary.notificationCount > 0))
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) connect.refresh()
      else if (buttonCode === Qt.MiddleButton && root.primary) connect.ping(root.primary.id)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        root.cursorActive = true
        root.moveCursor(dx, dy)
      }
      blocked: smsView.editorFocused || notifyView.editorFocused
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.goBack()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") connect.refresh()
        else if (t === "m" || t === "M") {
          if (root.selectedDevice) root.runAction({ id: "messages" })
        }
        else if (t === "n" || t === "N") {
          if (root.selectedDevice) root.runAction({ id: "notifications" })
        }
        else if (t === "d" || t === "D") {
          if (root.view === "notifications") notifyView.dismissCurrent()
        }
        else if (t === "p" || t === "P") { if (root.selectedDevice) connect.ping(root.selectedDevice.id) }
        else if (t === "f" || t === "F") { if (root.selectedDevice) connect.ring(root.selectedDevice.id) }
        else if (t === "c" || t === "C") { if (root.selectedDevice) connect.sendClipboard(root.selectedDevice.id) }
        else if (t === "s" || t === "S") { if (root.selectedDevice) connect.shareFile(root.selectedDevice.id) }
        else if (t === "i" || t === "I") connect.setup()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        onContentYChanged: {
          if (root.view === "sms" && smsView.page === "thread" && contentY < 48)
            smsView.loadOlder()
        }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          Item {
            id: header
            visible: connect.installed && root.view === "main"
            width: parent.width
            implicitHeight: hero.implicitHeight
            readonly property bool ringVisible: root.headerHasCursor
            function focusHero() {
              root.cursorActive = true
              root.focusSection = "header"
            }

            PanelHero {
              id: hero
              width: parent.width
              title: "Connect"
              meta: connect.active ? root.heroPhraseText : "Turned off"
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: connect.active ? 1.0 : 0.5
              iconComponent: Component {
                ConnectIcon {
                  iconSize: Style.font.display
                  color: root.phoneLive ? root.foreground : root.dim
                }
              }
              trailingControl: Component {
                ToggleSwitch {
                  id: powerSwitch
                  visible: connect.installed
                  checked: connect.active
                  busy: connect.busy
                  hasCursor: header.ringVisible
                  foreground: hero.foreground
                  onHovered: function(on) { if (on) header.focusHero() }
                  onToggled: connect.toggleRunning()

                  PanelToolTip {
                    visible: powerSwitch.containsMouse
                    text: root.toggleHint
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }

          Text {
            visible: connect.actionStatus !== "" || connect.lastError !== ""
            width: parent.width
            text: connect.actionStatus !== "" ? connect.actionStatus : connect.lastError
            color: connect.lastError !== "" && connect.actionStatus === "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          SetupButton {
            id: setupButton
            visible: !connect.installed
            width: parent.width
          }

          NotificationsView {
            id: notifyView
            visible: root.view === "notifications"
            width: parent.width
            service: connect
            device: root.smsDevice || root.selectedDevice
            foreground: root.foreground
            dim: root.dim
            fontFamily: root.fontFamily
            cursorActive: root.cursorActive
            onBackRequested: {
              root.view = "main"
              root.smsDevice = null
              root.armCursor()
              Qt.callLater(function() { keyCatcher.forceActiveFocus() })
            }
            onReleaseEditor: Qt.callLater(function() { keyCatcher.forceActiveFocus() })
          }

          SmsView {
            id: smsView
            visible: root.view === "sms"
            width: parent.width
            service: connect
            device: root.smsDevice || root.selectedDevice
            foreground: root.foreground
            dim: root.dim
            fontFamily: root.fontFamily
            cursorActive: root.cursorActive
            onBackRequested: {
              root.view = "main"
              root.smsDevice = null
              root.armCursor()
              Qt.callLater(function() { keyCatcher.forceActiveFocus() })
            }
            onReleaseEditor: Qt.callLater(function() { keyCatcher.forceActiveFocus() })
            onScrollToEnd: root.pinThreadBottom()
            onPreserveScroll: {
              root._savedY = panelFlick.contentY
              root._savedH = panelFlick.contentHeight
              root._keepScroll = true
            }
          }

          Column {
            visible: connect.installed && connect.active && root.view === "main"
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "DEVICES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: connect.devices.length === 0
              width: parent.width
              text: "Open KDE Connect on your phone, same Wi-Fi."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
            }

            Column {
              id: deviceColumn
              visible: connect.devices.length > 0
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                id: deviceRepeater
                model: connect.devices
                DeviceRow {
                  required property var modelData
                  required property int index
                  width: deviceColumn.width
                  device: modelData
                  rowIndex: index
                }
              }
            }

            PanelSeparator {
              visible: root.actions.length > 0
              foreground: root.foreground
            }

            Column {
              visible: root.actions.length > 0
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                id: actionRepeater
                model: root.actions
                ActionRow {
                  required property var modelData
                  required property int index
                  width: parent.width
                  action: modelData
                  rowIndex: index
                }
              }
            }
          }
        }
      }
    }
  }

  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && connect.active && root.phoneLive
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: hero
      property: "metaOpacity"
      to: 0.0
      duration: 180
      easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
    }
    PropertyAnimation {
      target: hero
      property: "metaOpacity"
      to: 1.0
      duration: 260
      easing.type: Easing.InQuad
    }
  }

  component SetupButton: CursorSurface {
    id: setupButton
    hasCursor: root.cursorActive && root.focusSection === "setup"
    foreground: root.foreground
    implicitHeight: setupRow.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        root.cursorActive = true
        root.focusSection = "setup"
      }
      onClicked: connect.setup()
    }

    RowLayout {
      id: setupRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      ConnectIcon {
        iconSize: Style.font.heading
        color: root.foreground
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)
        Text {
          text: "Install Connect"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          Layout.fillWidth: true
        }
        Text {
          text: "Adds kdeconnect, opens the ports, starts the daemon"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }

      PanelActionButton {
        iconText: "󰏔"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: connect.setup()
      }
    }
  }

  component DeviceRow: CursorSurface {
    id: deviceRow
    property var device: null
    property int rowIndex: 0
    hasCursor: root.cursorActive && root.focusSection === "devices" && root.deviceIndex === rowIndex
    foreground: root.foreground
    implicitHeight: deviceInner.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onEntered: root.setDeviceCursor(deviceRow.rowIndex)
      onClicked: root.setDeviceCursor(deviceRow.rowIndex)
    }

    RowLayout {
      id: deviceInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: Model.typeIcon(deviceRow.device ? deviceRow.device.type : "")
        color: deviceRow.device && deviceRow.device.reachable ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.heading
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)
        Text {
          textFormat: Text.PlainText
          text: deviceRow.device ? deviceRow.device.name : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
        Text {
          textFormat: Text.PlainText
          text: Model.deviceMeta(deviceRow.device)
          color: deviceRow.device && deviceRow.device.pairRequestedByPeer ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    property var action: null
    property int rowIndex: 0
    hasCursor: root.cursorActive && root.focusSection === "actions" && root.actionIndex === rowIndex
    foreground: root.foreground
    implicitHeight: actionInner.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setActionCursor(actionRow.rowIndex)
      onClicked: root.runAction(actionRow.action)
    }

    RowLayout {
      id: actionInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: actionRow.action ? actionRow.action.icon : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
      Text {
        text: actionRow.action ? actionRow.action.label : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        Layout.fillWidth: true
      }
    }
  }
}
