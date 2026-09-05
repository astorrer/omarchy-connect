const fs = require("fs")
const path = require("path")
const vm = require("vm")

const source = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8")
const sandbox = {}
vm.createContext(sandbox)
vm.runInContext(source, sandbox)

function assert(cond, message) {
  if (!cond) throw new Error(message)
}

assert(sandbox.parseStatus("").ok === false, "empty status fails")
assert(sandbox.parseStatus("{").ok === false, "bad json fails")

const status = sandbox.parseStatus(JSON.stringify({
  ok: true,
  installed: true,
  running: true,
  devices: [
    { id: "b", name: "Tablet", paired: true, reachable: false, battery: 40 },
    { id: "a", name: "Phone", paired: true, reachable: true, battery: 81, charging: true }
  ]
}))
assert(status.ok === true, "status ok")
assert(sandbox.primaryDevice(status.devices).id === "a", "primary is reachable paired")
assert(sandbox.batteryText(status.devices[1]) === "81% charging", "charging battery text")
assert(sandbox.deviceMeta(status.devices[1]).indexOf("81%") !== -1, "meta includes battery")
assert(sandbox.actionRows(status.devices[1]).some((row) => row.id === "ping"), "reachable paired has ping")
assert(sandbox.actionRows(status.devices[1]).some((row) => row.id === "messages"), "reachable paired has messages")
assert(sandbox.actionRows({ pairRequestedByPeer: true }).some((row) => row.id === "accept"), "incoming pair can accept")
assert(sandbox.typeIcon("tablet") === "󰓹", "tablet icon")
assert(sandbox.typeIcon("smartphone") === "󰄜", "phone icon")
assert(sandbox.conversationTitle({ title: "Ada" }) === "Ada", "explicit title")
assert(sandbox.conversationTitle({ addresses: ["+1", "+2"] }) === "+1 +1", "group title")
assert(sandbox.previewText({ body: "  hello\nthere " }) === "hello there", "preview squashes whitespace")
assert(sandbox.formatSmsTime(Date.now()).indexOf("M") !== -1, "today uses am/pm")

console.log("ok")
