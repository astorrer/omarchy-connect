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
  if (device.pairRequestedByPeer) {
    return [
      { id: "accept", label: "Accept pairing", icon: "󰄬" },
      { id: "reject", label: "Decline", icon: "󰅖" }
    ]
  }
  if (!device.paired) {
    return [{ id: "pair", label: "Request pairing", icon: "󰌹" }]
  }
  if (!device.reachable) {
    return [{ id: "unpair", label: "Unpair", icon: "󰌺" }]
  }
  var rows = [
    { id: "messages", label: "Messages", icon: "󰍥" },
    { id: "ping", label: "Ping", icon: "󰐷" },
    { id: "ring", label: "Ring phone", icon: "󰂜" },
    { id: "clipboard", label: "Send clipboard", icon: "󰅌" },
    { id: "file", label: "Send file", icon: "󰈔" },
    { id: "unpair", label: "Unpair", icon: "󰌺" }
  ]
  return rows
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

function barIcon(installed, running, device) {
  if (!installed) return "󰄜"
  if (!running) return "󰄜"
  if (device && device.pairRequestedByPeer) return "󰂜"
  if (device && device.paired && device.reachable) return "󰄜"
  return "󰄜"
}
