import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})

  property bool installed: false
  property bool running: false
  property string announcedName: ""
  property var devices: []
  property var conversations: []
  property var messages: []
  property bool smsLoading: false
  property bool refreshing: false
  property string actionStatus: ""
  property string lastError: ""
  property string daemonPath: ""

  property int _desired: -1
  readonly property bool active: _desired === -1 ? running : (_desired === 1)
  readonly property var primary: Model.primaryDevice(devices)
  readonly property bool busy: statusProcess.running || actionProcess.running || setupProcess.running || pickerProcess.running || smsProcess.running
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 8, 3, 120)
  readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("connect.py").toString().replace(/^file:\/\//, ""))
  readonly property string setupPath: decodeURIComponent(Qt.resolvedUrl("setup.sh").toString().replace(/^file:\/\//, ""))

  property string _statusOutput: ""
  property string _pendingAction: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  function helper(args) {
    return ["python3", helperPath].concat(args)
  }

  function refresh() {
    if (statusProcess.running || helperPath === "") return
    refreshing = true
    statusProcess.command = helper(["status"])
    statusProcess.running = true
  }

  function applyStatus(raw) {
    var parsed = Model.parseStatus(raw)
    if (!parsed.ok && parsed.lastError) {
      lastError = parsed.lastError
      return
    }
    installed = parsed.installed === true
    running = parsed.running === true
    if (_desired !== -1 && running === (_desired === 1)) _desired = -1
    announcedName = String(parsed.announcedName || "")
    daemonPath = String(parsed.daemonPath || "")
    devices = parsed.devices || []
    if (parsed.error) lastError = String(parsed.error)
    else lastError = ""
  }

  function runAction(args, label) {
    if (actionProcess.running) return
    _pendingAction = label || ""
    if (label) {
      actionStatus = label
      actionStatusTimer.restart()
    }
    actionProcess.command = helper(args)
    actionProcess.running = true
  }

  function startDaemon() {
    _desired = 1
    runAction(["start"], "Starting…")
  }

  function stopDaemon() {
    _desired = 0
    runAction(["stop"], "Stopping…")
  }

  function toggleRunning() {
    if (active) stopDaemon()
    else startDaemon()
  }

  function ping(id) { runAction(["ping", id], "Pinging…") }
  function ring(id) { runAction(["ring", id], "Ringing…") }
  function pair(id) { runAction(["pair", id], "Requesting pair…") }
  function unpair(id) { runAction(["unpair", id], "Unpairing…") }
  function accept(id) { runAction(["accept", id], "Accepting…") }
  function reject(id) { runAction(["reject", id], "Declining…") }
  function sendClipboard(id) { runAction(["send-clipboard", id], "Sending clipboard…") }

  function loadConversations(id) {
    if (!id || smsProcess.running) return
    smsLoading = true
    lastError = ""
    smsProcess._kind = "conversations"
    smsProcess.command = helper(["conversations", id])
    smsProcess.running = true
  }

  function loadThread(id, threadId) {
    if (!id || smsProcess.running) return
    smsLoading = true
    lastError = ""
    smsProcess._kind = "thread"
    smsProcess.command = helper(["conversation", id, String(threadId)])
    smsProcess.running = true
  }

  function smsReply(id, threadId, text) {
    runAction(["sms-reply", id, String(threadId), text], "Sending…")
  }

  function smsSend(id, number, text) {
    runAction(["sms-send", id, number, text], "Sending…")
  }

  function smsApp(id) {
    runAction(["sms-app", id], "Opening messages…")
  }

  function shareFile(id) {
    if (pickerProcess.running || !id) return
    pickerProcess.command = ["omarchy-file-select", "--title", "Send to phone", "--multiple"]
    pickerProcess.running = true
    pickerProcess._deviceId = id
  }

  function setup() {
    if (setupProcess.running) return
    actionStatus = "Opening installer…"
    actionStatusTimer.restart()
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", setupPath])
    settleTimer.restart()
  }

  Timer {
    id: refreshTimer
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: actionStatusTimer
    interval: 2200
    repeat: false
    onTriggered: root.actionStatus = ""
  }

  Timer {
    id: delayedRefresh
    interval: 800
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: settleTimer
    interval: 2000
    repeat: true
    running: false
    property int ticks: 0
    onTriggered: {
      ticks += 1
      root.refresh()
      if ((root.installed && root.running) || ticks >= 8) {
        ticks = 0
        settleTimer.running = false
      }
    }
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true }
    stderr: StdioCollector { id: statusStderr; waitForEnd: true }
    onExited: function() {
      root.refreshing = false
      root.applyStatus(statusStdout.text)
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function() {
      var parsed = Model.parseStatus(actionStdout.text)
      if (parsed && parsed.ok === false && (parsed.error || parsed.lastError)) {
        root.lastError = String(parsed.error || parsed.lastError)
        root.actionStatus = ""
        root._desired = -1
      } else {
        root.lastError = ""
      }
      delayedRefresh.restart()
    }
  }

  Process {
    id: pickerProcess
    property string _deviceId: ""
    running: false
    command: []
    stdout: StdioCollector { id: pickerStdout; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) return
      var lines = String(pickerStdout.text || "").split("\n")
      for (var i = 0; i < lines.length; i++) {
        var path = lines[i].trim()
        if (path !== "") root.runAction(["share-file", pickerProcess._deviceId, path], "Sending file…")
      }
    }
  }

  Process {
    id: setupProcess
    running: false
    command: []
  }

  Process {
    id: smsProcess
    property string _kind: ""
    running: false
    command: []
    stdout: StdioCollector { id: smsStdout; waitForEnd: true }
    onExited: function() {
      root.smsLoading = false
      var parsed = Model.parseStatus(smsStdout.text)
      if (parsed && parsed.ok === false) {
        root.lastError = String(parsed.error || parsed.lastError || "SMS failed")
        return
      }
      root.lastError = ""
      if (smsProcess._kind === "conversations") root.conversations = parsed.conversations || []
      else if (smsProcess._kind === "thread") root.messages = parsed.messages || []
    }
  }
}
