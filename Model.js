var PLUGIN_VERSION = "1.2.3"
var PROJECT_URL = "https://github.com/astorrer/omarchy-connect"

function scrollFlickToItem(flick, item, margin) {
  if (!flick || !item) return
  var m = margin || 8
  var point = item.mapToItem(flick.contentItem, 0, 0)
  if (!point) return
  var top = point.y
  var bottom = top + Math.max(item.height || 0, item.implicitHeight || 0)
  var viewTop = flick.contentY
  var viewBottom = viewTop + flick.height
  var maxY = Math.max(0, flick.contentHeight - flick.height)
  if (top < viewTop + m) flick.contentY = Math.max(0, top - m)
  else if (bottom > viewBottom - m) flick.contentY = Math.min(maxY, bottom + m - flick.height)
}

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

function kindColumns(kind, count) {
  var n = Math.max(1, count || 1)
  if (kind === "inbox" || kind === "choice") return Math.min(2, n)
  if (kind === "danger") return 1
  return n
}

function kindRange(actions, index) {
  var list = actions || []
  if (list.length === 0) return { start: 0, count: 0, kind: "" }
  var i = Math.max(0, Math.min(list.length - 1, index | 0))
  var kind = list[i].kind
  var start = i
  while (start > 0 && list[start - 1].kind === kind) start--
  var end = i
  while (end + 1 < list.length && list[end + 1].kind === kind) end++
  return { start: start, count: end - start + 1, kind: kind }
}

function indexInGroupColumn(actions, indexInGroup, col, fromEnd) {
  var range = kindRange(actions, indexInGroup)
  if (range.count <= 0) return 0
  var cols = kindColumns(range.kind, range.count)
  var c = Math.max(0, Math.min(cols - 1, col | 0))
  var row = fromEnd ? Math.ceil(range.count / cols) - 1 : 0
  var local = row * cols + c
  if (local >= range.count) local = range.count - 1
  return range.start + local
}

function moveActionIndex(actions, current, dx, dy) {
  var list = actions || []
  if (list.length === 0) return 0
  var i = Math.max(0, Math.min(list.length - 1, current | 0))
  if (!dx && !dy) return i
  var range = kindRange(list, i)
  var cols = kindColumns(range.kind, range.count)
  var local = i - range.start
  var row = Math.floor(local / cols)
  var col = local % cols
  var rows = Math.ceil(range.count / cols)
  if (dx && !dy) {
    var nextCol = col + dx
    var nextLocal = row * cols + nextCol
    if (nextCol >= 0 && nextCol < cols && nextLocal < range.count) return range.start + nextLocal
    return i
  }
  if (dy) {
    var nextRow = row + dy
    if (nextRow >= 0 && nextRow < rows) {
      var stepped = nextRow * cols + col
      if (stepped >= range.count) stepped = range.count - 1
      return range.start + stepped
    }
    if (dy > 0) {
      var after = range.start + range.count
      if (after >= list.length) return i
      return indexInGroupColumn(list, after, col, false)
    }
    if (range.start === 0) return -1
    return indexInGroupColumn(list, range.start - 1, col, true)
  }
  return i
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

function attachmentPreviewLabel(item) {
  if (!item) return "Attachment"
  if (item.kind === "image" || (item.mime && String(item.mime).indexOf("image/") === 0)) return "Photo"
  var label = String(item.label || item.name || "").trim()
  if (label) return label
  return "Attachment"
}

function attachmentSummary(item) {
  var atts = item && item.attachments
  if (atts && typeof atts.length === "number" && atts.length > 0) {
    if (atts.length === 1) return attachmentPreviewLabel(atts[0])
    return atts.length + " attachments"
  }
  if (item && item.attachmentCount > 0) return "Attachment"
  return ""
}

function previewText(conversation) {
  var body = String((conversation && conversation.body) || "").replace(/\s+/g, " ").trim()
  if (body) return body
  return attachmentSummary(conversation)
}

function messageText(message) {
  return String((message && message.body) || "")
}

function messageAttachments(message) {
  var atts = message && message.attachments
  if (atts && typeof atts.length === "number") return atts
  return []
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
