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
  moduleName: "io.github.astorrer.konnectarchy"
  ipcTarget: "io.github.astorrer.konnectarchy"
  manageIpc: false

  readonly property bool hideWhenDisconnected: !!setting("hideWhenDisconnected", false)
  readonly property bool badgeNotifications: setting("badgeNotifications", true) !== false
  readonly property bool hideSmsNotifications: setting("hideSmsNotifications", true) !== false
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
  readonly property string toggleHint: connect.active ? "Stop Konnectarchy" : "Start Konnectarchy"
  readonly property var selectedDevice: {
    if (connect.devices.length === 0) return null
    return connect.devices[Math.max(0, Math.min(deviceIndex, connect.devices.length - 1))]
  }
  readonly property var actions: Model.actionRows(selectedDevice, hideSmsNotifications)

  property int phraseIndex: 0
  property int settingIndex: 0
  readonly property var livePhrases: Model.heroPhrases(primary, hideSmsNotifications)
  readonly property string heroPhraseText: {
    if (!connect.installed) return "Not installed"
    if (!connect.active) return "Turned off"
    if (phoneLive && livePhrases.length > 0) return livePhrases[phraseIndex % livePhrases.length]
    if (connect.devices.length > 0) return "Waiting to pair"
    return "No devices yet"
  }
  readonly property var inboxActions: Model.actionsOfKind(actions, "inbox")
  readonly property var mediaActions: Model.actionsOfKind(actions, "media")
  readonly property var mediaState: Model.mediaState(selectedDevice)
  readonly property var toolActions: Model.actionsOfKind(actions, "tool")
  readonly property var choiceActions: Model.actionsOfKind(actions, "choice")
  readonly property var dangerActions: Model.actionsOfKind(actions, "danger")

  property string view: "main"
  property var smsDevice: null
  property string focusSection: "header"
  property int deviceIndex: 0
  property int actionIndex: 0
  property bool cursorActive: false
  property bool unpairConfirmOpen: false
  property var unpairDevice: null

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
    if (unpairConfirmOpen) {
      cancelUnpair()
      return
    }
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
    if (view === "settings") {
      view = "main"
      armCursor()
      return
    }
    close()
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function openSettings() {
    view = "settings"
    settingIndex = 0
    cursorActive = true
    focusSection = "settings"
  }

  function openProject() {
    Qt.openUrlExternally(Model.PROJECT_URL)
  }

  function bumpRefresh(delta) {
    var next = root.connect.refreshIntervalSec + delta
    if (next < 3) next = 3
    if (next > 120) next = 120
    persistSettings({ refreshIntervalSec: next })
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
    if (focusSection === "settings") {
      if (settingIndex === 0) return badgeRow
      if (settingIndex === 1) return hideRow
      if (settingIndex === 2) return hideSmsRow
      return intervalRow
    }
    if (focusSection === "actions") {
      var action = actions[actionIndex]
      if (!action) return null
      if (action.kind === "inbox" && inboxRepeater) return inboxRepeater.itemAt(Model.indexInKind(actions, "inbox", actionIndex))
      if (action.kind === "media" && mediaRepeater) return mediaRepeater.itemAt(Model.indexInKind(actions, "media", actionIndex))
      if (action.kind === "tool" && toolRepeater) return toolRepeater.itemAt(Model.indexInKind(actions, "tool", actionIndex))
      if (action.kind === "choice" && choiceRepeater) return choiceRepeater.itemAt(Model.indexInKind(actions, "choice", actionIndex))
      if (action.kind === "danger" && dangerRepeater) return dangerRepeater.itemAt(Model.indexInKind(actions, "danger", actionIndex))
    }
    return null
  }

  function scrollCursorIntoView() {
    if (view === "sms") {
      smsView.scrollCursorIntoView()
      return
    }
    if (view === "notifications") {
      notifyView.scrollCursorIntoView()
      return
    }
    scrollItemIntoView(currentItem())
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    if (unpairConfirmOpen) {
      if (dx !== 0) unpairConfirm.selectedIndex = unpairConfirm.selectedIndex === 0 ? 1 : 0
      return
    }
    if (view === "settings") {
      if (dx !== 0 && settingIndex === 3) {
        bumpRefresh(dx > 0 ? 1 : -1)
        return
      }
      if (dx < 0) {
        goBack()
        return
      }
      if (dx > 0) {
        activateCursor()
        return
      }
      settingIndex = Math.max(0, Math.min(3, settingIndex + dy))
      scrollCursorIntoView()
      return
    }
    if (view === "sms") {
      if (dx !== 0 && dy === 0) {
        if (smsView.inboxToolsFocused) {
          if (smsView.listIndex === smsView.inboxToolStart && dx < 0) {
            goBack()
            return
          }
          smsView.cursorActive = true
          smsView.moveList(dx, 0)
          scrollCursorIntoView()
          return
        }
        if (dx > 0) activateCursor()
        else goBack()
        return
      }
      smsView.cursorActive = true
      smsView.moveList(0, dy)
      scrollCursorIntoView()
      return
    }
    if (view === "notifications") {
      if (dx !== 0 && dy === 0) {
        if (dx > 0) activateCursor()
        else goBack()
        return
      }
      notifyView.cursorActive = true
      notifyView.moveList(dy)
      scrollCursorIntoView()
      return
    }
    ensureCursor()
    if (focusSection === "actions") {
      var next = Model.moveActionIndex(actions, actionIndex, dx, dy)
      if (next < 0) {
        focusSection = "devices"
        if (connect.devices.length > 0) deviceIndex = connect.devices.length - 1
      } else {
        actionIndex = next
      }
      scrollCursorIntoView()
      return
    }
    if (dx !== 0 && dy === 0) {
      if (dx > 0) activateCursor()
      else goBack()
      return
    }
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
    }
    scrollCursorIntoView()
  }

  function activateCursor() {
    if (unpairConfirmOpen) {
      if (unpairConfirm.selectedIndex === 0) cancelUnpair()
      else confirmUnpair()
      return
    }
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
    if (focusSection === "settings") {
      if (settingIndex === 0) persistSettings({ badgeNotifications: !root.badgeNotifications })
      else if (settingIndex === 1) persistSettings({ hideWhenDisconnected: !root.hideWhenDisconnected })
      else if (settingIndex === 2) persistSettings({ hideSmsNotifications: !root.hideSmsNotifications })
      else bumpRefresh(1)
      return
    }
    if (focusSection === "header") {
      connect.toggleRunning()
      return
    }
    if (focusSection === "devices") {
      connect.openKdeConnect()
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
    else if (action.id === "media-previous") connect.mediaAction(id, "previous")
    else if (action.id === "media-toggle") connect.mediaAction(id, "toggle")
    else if (action.id === "media-next") connect.mediaAction(id, "next")
    else if (action.id === "clipboard") connect.sendClipboard(id)
    else if (action.id === "file") connect.shareFile(id)
    else if (action.id === "pair") connect.pair(id)
    else if (action.id === "unpair") requestUnpair(selectedDevice)
    else if (action.id === "accept") connect.accept(id)
    else if (action.id === "reject") connect.reject(id)
  }

  function requestUnpair(device) {
    if (!device) return
    unpairDevice = device
    unpairConfirm.selectedIndex = 0
    unpairConfirmOpen = true
  }

  function cancelUnpair() {
    unpairConfirmOpen = false
    unpairDevice = null
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function confirmUnpair() {
    var device = unpairDevice
    unpairConfirmOpen = false
    unpairDevice = null
    if (device) connect.unpair(device.id)
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
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
    unpairConfirmOpen = false
    unpairDevice = null
    armCursor()
    connect.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  } else {
    unpairConfirmOpen = false
    unpairDevice = null
  }

  Service {
    id: connect
    settings: root.settings
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
    tooltipText: "Konnectarchy"
    iconComponent: Component {
      Item {
        ConnectIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barIconColor
          dimmed: !root.phoneLive
          badge: !!(root.primary && (root.primary.pairRequestedByPeer || (root.badgeNotifications && Model.notificationBadgeCount(root.primary, root.hideSmsNotifications) > 0)))
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
    contentHeight: (root.view === "sms" || root.view === "notifications")
      ? panel.fittedContentHeight(Style.space(560), Style.space(560))
      : panel.fittedContentHeight(column.implicitHeight, Style.space(560))

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
      onTabRequested: function(direction) {
        if (root.unpairConfirmOpen) {
          unpairConfirm.selectedIndex = unpairConfirm.selectedIndex === 0 ? 1 : 0
          return
        }
        root.switchPanel(direction)
      }
      onTextKey: function(t) {
        if (root.unpairConfirmOpen) return
        if (t === "r" || t === "R") {
          connect.refresh()
          if (root.view === "notifications" && root.selectedDevice)
            connect.loadNotifications(root.selectedDevice.id)
          else if (root.view === "sms" && smsView.page === "inbox" && root.selectedDevice)
            connect.loadConversations(root.selectedDevice.id)
          else if (root.view === "sms" && smsView.page === "thread")
            connect.refreshThread()
        }
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
        else if (t === "t" || t === "T") { if (root.selectedDevice) connect.mediaAction(root.selectedDevice.id, "toggle") }
        else if (t === "[") { if (root.selectedDevice) connect.mediaAction(root.selectedDevice.id, "previous") }
        else if (t === "]") { if (root.selectedDevice) connect.mediaAction(root.selectedDevice.id, "next") }
        else if (t === "f" || t === "F") { if (root.selectedDevice) connect.ring(root.selectedDevice.id) }
        else if (t === "y" || t === "Y") {
          if (root.view === "sms") smsView.copyPrimary()
          else if (root.view === "notifications") notifyView.copyPrimary()
        }
        else if (t === "c" || t === "C") { if (root.selectedDevice) connect.sendClipboard(root.selectedDevice.id) }
        else if (t === "s" || t === "S") { if (root.selectedDevice) connect.shareFile(root.selectedDevice.id) }
        else if (t === "i" || t === "I") connect.setup()
        else if (t === ",") root.openSettings()
      }

      ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SmsView {
          id: smsView
          visible: root.view === "sms"
          Layout.fillWidth: true
          Layout.fillHeight: visible
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

        NotificationsView {
          id: notifyView
          visible: root.view === "notifications"
          Layout.fillWidth: true
          Layout.fillHeight: visible
          service: connect
          device: root.smsDevice || root.selectedDevice
          foreground: root.foreground
          dim: root.dim
          fontFamily: root.fontFamily
          cursorActive: root.cursorActive
          hideSmsNotifications: root.hideSmsNotifications
          onBackRequested: {
            root.view = "main"
            root.smsDevice = null
            root.armCursor()
            Qt.callLater(function() { keyCatcher.forceActiveFocus() })
          }
          onReleaseEditor: Qt.callLater(function() { keyCatcher.forceActiveFocus() })
        }

        Flickable {
          id: panelFlick
          visible: root.view === "main" || root.view === "settings"
          Layout.fillWidth: true
          Layout.fillHeight: visible
          contentWidth: width
          contentHeight: column.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: column
            width: panelFlick.width
            spacing: Style.space(12)

          Item {
            id: header
            visible: connect.installed && (root.view === "main" || root.view === "settings")
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
              title: "Konnectarchy"
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
              visible: root.mediaActions.length > 0
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader {
                text: "NOW PLAYING"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              ColumnLayout {
                width: parent.width
                spacing: Style.space(1)
                Text {
                  textFormat: Text.PlainText
                  text: root.mediaState ? root.mediaState.title : ""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
                Text {
                  textFormat: Text.PlainText
                  text: Model.mediaMeta(root.mediaState)
                  visible: text !== ""
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }

              Row {
                id: mediaRow
                width: parent.width
                spacing: Style.space(6)
                Repeater {
                  id: mediaRepeater
                  model: root.mediaActions
                  Button {
                    required property var modelData
                    required property int index
                    width: mediaRow.width > 0 && root.mediaActions.length > 0
                      ? (mediaRow.width - mediaRow.spacing * (root.mediaActions.length - 1)) / root.mediaActions.length
                      : 0
                    iconText: modelData.icon
                    text: modelData.label
                    fontSize: Style.font.caption
                    iconSize: Style.font.title
                    bordered: true
                    fontFamily: root.fontFamily
                    foreground: root.foreground
                    horizontalPadding: Style.space(4)
                    hasCursor: root.cursorActive && root.focusSection === "actions" && root.actionIndex === modelData.index
                    onClicked: root.runAction(modelData)
                    onHovered: function(on) {
                      if (!on) return
                      root.cursorActive = true
                      root.focusSection = "actions"
                      root.actionIndex = modelData.index
                    }
                  }
                }
              }

              Rectangle {
                visible: root.mediaActions.length > 0
                width: parent.width
                height: 1
                color: root.dim
                opacity: 0.35
              }
            }

            Grid {
              id: inboxGrid
              visible: root.inboxActions.length > 0
              width: parent.width
              columns: Math.min(2, root.inboxActions.length)
              columnSpacing: Style.space(6)
              rowSpacing: Style.space(6)
              Repeater {
                id: inboxRepeater
                model: root.inboxActions
                Button {
                  required property var modelData
                  required property int index
                  width: inboxGrid.columns === 1 ? inboxGrid.width : (inboxGrid.width - inboxGrid.columnSpacing) / 2
                  iconText: modelData.icon
                  text: modelData.label
                  bordered: true
                  fontFamily: root.fontFamily
                  foreground: root.foreground
                  hasCursor: root.cursorActive && root.focusSection === "actions" && root.actionIndex === modelData.index
                  onClicked: root.runAction(modelData)
                  onHovered: function(on) {
                    if (!on) return
                    root.cursorActive = true
                    root.focusSection = "actions"
                    root.actionIndex = modelData.index
                  }
                }
              }
            }

            Row {
              id: toolRow
              visible: root.toolActions.length > 0
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                id: toolRepeater
                model: root.toolActions
                Button {
                  required property var modelData
                  required property int index
                  width: toolRow.width > 0 && root.toolActions.length > 0
                    ? (toolRow.width - toolRow.spacing * (root.toolActions.length - 1)) / root.toolActions.length
                    : 0
                  iconText: modelData.icon
                  text: modelData.label
                  fontSize: Style.font.caption
                  iconSize: Style.font.title
                  bordered: true
                  fontFamily: root.fontFamily
                  foreground: root.foreground
                  horizontalPadding: Style.space(4)
                  hasCursor: root.cursorActive && root.focusSection === "actions" && root.actionIndex === modelData.index
                  onClicked: root.runAction(modelData)
                  onHovered: function(on) {
                    if (!on) return
                    root.cursorActive = true
                    root.focusSection = "actions"
                    root.actionIndex = modelData.index
                  }
                }
              }
            }

            Grid {
              id: choiceGrid
              visible: root.choiceActions.length > 0
              width: parent.width
              columns: Math.min(2, Math.max(1, root.choiceActions.length))
              columnSpacing: Style.space(6)
              rowSpacing: Style.space(6)
              Repeater {
                id: choiceRepeater
                model: root.choiceActions
                Button {
                  required property var modelData
                  required property int index
                  width: choiceGrid.columns === 1 ? choiceGrid.width : (choiceGrid.width - choiceGrid.columnSpacing) / 2
                  iconText: modelData.icon
                  text: modelData.label
                  bordered: true
                  fontFamily: root.fontFamily
                  foreground: root.foreground
                  hasCursor: root.cursorActive && root.focusSection === "actions" && root.actionIndex === modelData.index
                  onClicked: root.runAction(modelData)
                  onHovered: function(on) {
                    if (!on) return
                    root.cursorActive = true
                    root.focusSection = "actions"
                    root.actionIndex = modelData.index
                  }
                }
              }
            }

            Column {
              visible: root.dangerActions.length > 0
              width: parent.width
              Repeater {
                id: dangerRepeater
                model: root.dangerActions
                ActionRow {
                  required property var modelData
                  required property int index
                  width: parent.width
                  action: modelData
                  rowIndex: modelData.index
                }
              }
            }

            Item {
              width: parent.width
              implicitHeight: footerRow.implicitHeight
              RowLayout {
                id: footerRow
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Style.space(8)
                Text {
                  text: "Konnectarchy " + Model.PLUGIN_VERSION
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openProject()
                  }
                }
                Item { Layout.fillWidth: true }
                PanelActionButton {
                  iconText: "󰒓"
                  tooltipText: "Settings"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  hasCursor: root.cursorActive && root.focusSection === "footer"
                  onClicked: root.openSettings()
                  onHovered: function(on) {
                    if (!on) return
                    root.cursorActive = true
                    root.focusSection = "footer"
                  }
                }
              }
            }
          }

          Column {
            visible: connect.installed && root.view === "settings"
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "SETTINGS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Toggle {
              id: badgeRow
              width: parent.width
              label: "Badge the bar"
              titleSize: Style.font.body
              checked: root.badgeNotifications
              foreground: root.foreground
              fontFamily: root.fontFamily
              hasCursor: root.cursorActive && root.focusSection === "settings" && root.settingIndex === 0
              onClicked: root.persistSettings({ badgeNotifications: !root.badgeNotifications })
              onHovered: function(on) {
                if (!on) return
                root.cursorActive = true
                root.focusSection = "settings"
                root.settingIndex = 0
              }
            }

            Toggle {
              id: hideRow
              width: parent.width
              label: "Hide when away"
              titleSize: Style.font.body
              checked: root.hideWhenDisconnected
              foreground: root.foreground
              fontFamily: root.fontFamily
              hasCursor: root.cursorActive && root.focusSection === "settings" && root.settingIndex === 1
              onClicked: root.persistSettings({ hideWhenDisconnected: !root.hideWhenDisconnected })
              onHovered: function(on) {
                if (!on) return
                root.cursorActive = true
                root.focusSection = "settings"
                root.settingIndex = 1
              }
            }

            Toggle {
              id: hideSmsRow
              width: parent.width
              label: "Hide SMS notices"
              titleSize: Style.font.body
              checked: root.hideSmsNotifications
              foreground: root.foreground
              fontFamily: root.fontFamily
              hasCursor: root.cursorActive && root.focusSection === "settings" && root.settingIndex === 2
              onClicked: root.persistSettings({ hideSmsNotifications: !root.hideSmsNotifications })
              onHovered: function(on) {
                if (!on) return
                root.cursorActive = true
                root.focusSection = "settings"
                root.settingIndex = 2
              }
            }

            CursorSurface {
              id: intervalRow
              width: parent.width
              hasCursor: root.cursorActive && root.focusSection === "settings" && root.settingIndex === 3
              foreground: root.foreground
              implicitHeight: intervalInner.implicitHeight + Style.spacing.rowPaddingX
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: { root.cursorActive = true; root.focusSection = "settings"; root.settingIndex = 3 }
              }
              RowLayout {
                id: intervalInner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)
                Text {
                  text: "Refresh every " + connect.refreshIntervalSec + "s"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  Layout.fillWidth: true
                }
                PanelActionButton {
                  iconText: "−"
                  tooltipText: "Faster"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.bumpRefresh(-1)
                }
                PanelActionButton {
                  iconText: "+"
                  tooltipText: "Slower"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.bumpRefresh(1)
                }
              }
            }
          }
        }
      }

      ConfirmDialog {
        id: unpairConfirm
        anchors.fill: parent
        z: 20
        opened: root.unpairConfirmOpen
        message: root.unpairDevice && root.unpairDevice.name
          ? "Unpair " + root.unpairDevice.name + "?"
          : "Unpair this phone?"
        cancelText: "Cancel"
        confirmText: "Unpair"
        background: Color.background
        foreground: root.foreground
        fontFamily: root.fontFamily
        onCanceled: root.cancelUnpair()
        onConfirmed: root.confirmUnpair()
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
      script: {
        var n = root.livePhrases.length
        root.phraseIndex = n > 0 ? (root.phraseIndex + 1) % n : 0
      }
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
          text: "Install Konnectarchy"
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
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setDeviceCursor(deviceRow.rowIndex)
      onClicked: {
        root.setDeviceCursor(deviceRow.rowIndex)
        connect.openKdeConnect()
      }
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
          text: Model.deviceMeta(deviceRow.device, root.hideSmsNotifications)
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
