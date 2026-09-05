var PLUGIN_VERSION = "1.1.0"
var PROJECT_URL = "https://github.com/astorrer/omarchy-connect"

function parseStatus(raw) {
  var text = String(raw || "").trim()
  if (text === "") return { ok: false, lastError: "Empty status" }
  try {
    var parsed = JSON.parse(text)
  } catch (error) {
    return { ok: false, lastError: "Could not read Connect status" }
  }
  if (!parsed || typeof parsed !== "object") return { ok: false, lastError: "Bad status payload" }
  parsed.ok = parsed.ok !== false
  parsed.devices = parsed.devices instanceof Array ? parsed.devices : []
  return parsed
}

function typeIcon(type) {
  var value = String(type || "").toLowerCase()
  if (value === "tablet") return "󰓹"
  if (value === "desktop" || value === "laptop") return "󰌢"
  if (value === "tv") return "󰠹"
  return "󰄜"
}

function batteryText(device) {
  if (!device || typeof device.battery !== "number" || device.battery < 0) return ""
  return device.battery + "%" + (device.charging ? " charging" : "")
}

function deviceMeta(device) {
  if (!device) return ""
  if (device.pairRequestedByPeer) return "Wants to pair"
  if (device.pairRequested) return "Pairing requested"
  if (!device.paired) return device.reachable ? "Nearby · not paired" : "Not paired"
  if (!device.reachable) return "Unavailable"
  var parts = []
  var battery = batteryText(device)
  if (battery) parts.push(battery)
  if (device.networkType) parts.push(String(device.networkType))
  if (typeof device.notificationCount === "number" && device.notificationCount > 0)
    parts.push(device.notificationCount === 1 ? "1 notification" : device.notificationCount + " notifications")
  return parts.length ? parts.join(" · ") : "Connected"
}

function primaryDevice(devices) {
  if (!devices || devices.length === 0) return null
  for (var i = 0; i < devices.length; i++) {
    if (devices[i].paired && devices[i].reachable) return devices[i]
  }
  for (var j = 0; j < devices.length; j++) {
    if (devices[j].pairRequestedByPeer) return devices[j]
  }
  return devices[0]
}

function actionRows(device) {
  if (!device) return []
  var rows = []
  if (device.pairRequestedByPeer) {
    rows = [
      { id: "accept", label: "Accept", icon: "󰄬", kind: "choice" },
      { id: "reject", label: "Decline", icon: "󰅖", kind: "choice" }
    ]
  } else if (!device.paired) {
    rows = [{ id: "pair", label: "Request pairing", icon: "󰌹", kind: "choice" }]
  } else if (!device.reachable) {
    rows = [{ id: "unpair", label: "Unpair", icon: "󰌺", kind: "danger" }]
  } else {
    var notifyLabel = "Notifications"
    var count = device.notificationCount
    if (typeof count === "number" && count > 0) notifyLabel = "Notifications (" + count + ")"
    rows = [
      { id: "notifications", label: notifyLabel, icon: "󰎕", kind: "inbox" },
      { id: "messages", label: "Messages", icon: "󰍥", kind: "inbox" },
      { id: "ping", label: "Ping", icon: "󰐷", kind: "tool" },
      { id: "ring", label: "Ring", icon: "󰂜", kind: "tool" },
      { id: "clipboard", label: "Clipboard", icon: "󰅌", kind: "tool" },
      { id: "file", label: "File", icon: "󰈔", kind: "tool" },
      { id: "unpair", label: "Unpair", icon: "󰌺", kind: "danger" }
    ]
  }
  for (var i = 0; i < rows.length; i++) rows[i].index = i
  return rows
}

function actionsOfKind(actions, kind) {
  var rows = []
  var list = actions || []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].kind === kind) rows.push(list[i])
  }
  return rows
}

function indexInKind(actions, kind, globalIndex) {
  var n = 0
  var list = actions || []
  for (var i = 0; i < list.length; i++) {
    if (!list[i] || list[i].kind !== kind) continue
    if (i === globalIndex) return n
    n++
  }
  return 0
}

function heroPhrases(device) {
  if (!device || !device.paired || !device.reachable) return []
  var name = String(device.name || "the phone")
  var short = name.split(" ")[0] || name
  var phrases = []
  var battery = device.battery
  var charging = device.charging === true
  if (typeof battery === "number" && battery >= 0) {
    if (charging) phrases.push(short + " is sipping wall power at " + battery + "%")
    else if (battery <= 12) phrases.push(short + " is running on fumes · " + battery + "%")
    else if (battery >= 90) phrases.push(short + " is topped up at " + battery + "%")
    else phrases.push(short + " is wandering at " + battery + "%")
  }
  var n = device.notificationCount
  if (typeof n === "number" && n > 0)
    phrases.push(n === 1 ? "One note is waiting in the pocket" : n + " notes waiting in the pocket")
  else phrases.push("Inbox is quiet. For now.")
  var net = String(device.networkType || "")
  if (net) phrases.push("On " + net + ", still in range")
  phrases.push("Ready to ping " + short)
  return phrases
}

function conversationTitle(conversation) {
  if (!conversation) return "Unknown"
  if (conversation.title) return String(conversation.title)
  var names = conversation.names
  if (names && typeof names.length === "number" && names.length > 0) return names.join(", ")
  var addresses = conversation.addresses
  if (!addresses || typeof addresses.length !== "number") addresses = []
  if (addresses.length === 0) return "Unknown"
  return addresses.map(String).join(", ")
}

function previewText(conversation) {
  var body = String((conversation && conversation.body) || "").replace(/\s+/g, " ").trim()
  if (body === "" && conversation && conversation.attachmentCount > 0) return "Attachment"
  return body
}

function messageText(message) {
  var body = String((message && message.body) || "")
  if (body !== "") return body
  if (message && message.attachmentCount > 0) return "Attachment"
  return ""
}

function formatSmsTime(ms) {
  var n = Number(ms)
  if (!isFinite(n) || n <= 0) return ""
  var date = new Date(n)
  var now = new Date()
  var sameDay = date.getFullYear() === now.getFullYear() && date.getMonth() === now.getMonth() && date.getDate() === now.getDate()
  if (sameDay) {
    var hours = date.getHours()
    var minutes = date.getMinutes()
    var suffix = hours >= 12 ? "PM" : "AM"
    hours = hours % 12
    if (hours === 0) hours = 12
    return hours + ":" + (minutes < 10 ? "0" : "") + minutes + " " + suffix
  }
  return (date.getMonth() + 1) + "/" + date.getDate()
}

function notificationTitle(item) {
  if (!item) return "Notification"
  var title = String(item.title || "").trim()
  if (title) return title
  var ticker = String(item.ticker || "").trim()
  if (ticker) return ticker
  return String(item.appName || "Notification")
}

function notificationPreview(item) {
  var text = String((item && item.text) || "").replace(/\s+/g, " ").trim()
  if (text) return text
  return String((item && item.ticker) || "").replace(/\s+/g, " ").trim()
}

function notificationMeta(item) {
  if (!item) return ""
  var app = String(item.appName || "").trim()
  if (item.canReply) return app ? app + " · reply" : "Reply"
  return app
}

function barIcon(installed, running, device) {
  if (!installed) return "󰄜"
  if (!running) return "󰄜"
  if (device && device.pairRequestedByPeer) return "󰂜"
  if (device && device.paired && device.reachable) return "󰄜"
  return "󰄜"
}
