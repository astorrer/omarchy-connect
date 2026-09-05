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
  return [
    { id: "ping", label: "Ping", icon: "󰐷" },
    { id: "ring", label: "Ring phone", icon: "󰂜" },
    { id: "clipboard", label: "Send clipboard", icon: "󰅌" },
    { id: "file", label: "Send file", icon: "󰈔" },
    { id: "unpair", label: "Unpair", icon: "󰌺" }
  ]
}

function barIcon(installed, running, device) {
  if (!installed) return "󰄜"
  if (!running) return "󰄜"
  if (device && device.pairRequestedByPeer) return "󰂜"
  if (device && device.paired && device.reachable) return "󰄜"
  return "󰄜"
}
