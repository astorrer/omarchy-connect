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
assert(sandbox.PLUGIN_VERSION.length > 0, "version string")
assert(sandbox.actionRows(status.devices[1])[0].id === "notifications", "notifications is the first action")
assert(sandbox.actionRows(status.devices[1])[0].kind === "inbox", "inbox kind")
assert(sandbox.actionsOfKind(sandbox.actionRows(status.devices[1]), "tool").length === 4, "four tools")
const pad = sandbox.actionRows({ paired: true, reachable: true, notificationCount: 1 })
assert(sandbox.moveActionIndex(pad, 0, 1, 0) === 1, "right notifications to messages")
assert(sandbox.moveActionIndex(pad, 1, -1, 0) === 0, "left messages to notifications")
assert(sandbox.moveActionIndex(pad, 1, 1, 0) === 1, "right from last inbox stays")
assert(sandbox.moveActionIndex(pad, 0, 0, 1) === 2, "down notifications to ping")
assert(sandbox.moveActionIndex(pad, 1, 0, 1) === 3, "down messages to ring")
assert(sandbox.moveActionIndex(pad, 2, 1, 0) === 3, "right ping to ring")
assert(sandbox.moveActionIndex(pad, 5, 0, 1) === 6, "down file to unpair")
assert(sandbox.moveActionIndex(pad, 2, 0, -1) === 0, "up ping to notifications")
assert(sandbox.moveActionIndex(pad, 0, 0, -1) === -1, "up from inbox leaves the pad")
assert(sandbox.heroPhrases({ paired: true, reachable: true, name: "Pixel 9", battery: 51, notificationCount: 2, networkType: "LTE" }).length >= 3, "live hero phrases")
assert(sandbox.heroPhrases({ paired: true, reachable: true, name: "Pixel 9", battery: 51, notificationCount: 2 }).some(function(p) { return p.indexOf("2 notes") !== -1 }), "phrase mentions notes")
assert(sandbox.heroPhrases({ paired: false, reachable: true }).length === 0, "no live phrases until paired")
assert(sandbox.actionRows(status.devices[1]).some((row) => row.id === "notifications"), "reachable paired has notifications")
assert(sandbox.actionRows({ paired: true, reachable: true, notificationCount: 3 }).some((row) => row.label.indexOf("3") !== -1), "notification count in label")
assert(sandbox.deviceMeta({ paired: true, reachable: true, battery: 80, notificationCount: 2 }).indexOf("2 notifications") !== -1, "device meta includes notification count")
assert(sandbox.notificationTitle({ title: "Door locked", appName: "Wyze" }) === "Door locked", "notification title")
assert(sandbox.notificationPreview({ text: "  hello\nthere " }) === "hello there", "notification preview")
assert(sandbox.notificationMeta({ appName: "Messages", canReply: true }) === "Messages · reply", "replyable meta")
assert(sandbox.isSmsNotification({ appName: "Messages" }) === true, "google messages is sms")
assert(sandbox.isSmsNotification({ appName: "Google Messages" }) === true, "google messages label is sms")
assert(sandbox.isSmsNotification({ appName: "Textra" }) === true, "textra is sms")
assert(sandbox.isSmsNotification({ appName: "WhatsApp" }) === false, "whatsapp is not sms")
assert(sandbox.isSmsNotification({ appName: "Signal" }) === false, "signal is not sms")
assert(sandbox.isSmsNotification({ appName: "Wyze" }) === false, "wyze is not sms")
assert(sandbox.visibleNotifications([{ appName: "Messages" }, { appName: "Wyze" }], true).length === 1, "hide sms leaves other apps")
assert(sandbox.visibleNotifications([{ appName: "Messages" }], false).length === 1, "show sms keeps messages")
assert(sandbox.actionRows({ pairRequestedByPeer: true }).some((row) => row.id === "accept"), "incoming pair can accept")
assert(sandbox.typeIcon("tablet") === "󰓹", "tablet icon")
assert(sandbox.typeIcon("smartphone") === "󰄜", "phone icon")
assert(sandbox.conversationTitle({ title: "Ada" }) === "Ada", "explicit title")
assert(sandbox.conversationTitle({ names: ["Ada", "Bob"] }) === "Ada, Bob", "names title")
assert(sandbox.conversationTitle({ addresses: ["+1", "+2"] }) === "+1, +2", "group title")
assert(sandbox.previewText({ body: "  hello\nthere " }) === "hello there", "preview squashes whitespace")
assert(sandbox.messageText({ body: "" }) === "", "empty message")
assert(sandbox.previewText({ body: "", attachments: [{ kind: "image", mime: "image/jpeg" }] }) === "Photo", "photo preview")
assert(sandbox.previewText({ body: "", attachments: [{ kind: "file", label: "a.pdf" }, { kind: "file", label: "b" }] }) === "2 attachments", "multi attachment preview")
assert(sandbox.previewText({ body: "", attachmentCount: 1 }) === "Attachment", "attachment placeholder")
assert(sandbox.formatSmsTime(Date.now()).indexOf("M") !== -1, "today uses am/pm")

function snippetValues(text) {
  return sandbox.copySnippets(text).map(function(item) { return item.kind + ":" + item.value })
}

assert(snippetValues("Your verification code is 123456").indexOf("code:123456") !== -1, "labeled 6-digit code")
assert(snippetValues("G-847291 is your Google verification code").indexOf("code:847291") !== -1, "google G- code")
assert(snippetValues("123456").indexOf("code:123456") !== -1, "whole message is a code")
assert(snippetValues("123 456").indexOf("code:123456") !== -1, "whole spaced code")
assert(snippetValues("Your code is 123-456").indexOf("code:123456") !== -1, "dashed code with cue")
assert(snippetValues("123456 is your Microsoft account verification code").indexOf("code:123456") !== -1, "code before cue")
assert(snippetValues("ENTER CODE: 998877").indexOf("code:998877") !== -1, "code label with colon")
assert(snippetValues("Your PIN is 4321").indexOf("code:4321") !== -1, "labeled pin")
assert(snippetValues("Your Airbnb code is HD3K8P").indexOf("code:HD3K8P") !== -1, "mixed alphanumeric code")
assert(snippetValues("Use 11223344 as your authentication code").indexOf("code:11223344") !== -1, "labeled 8-digit code")
assert(snippetValues("Hi mom, see you at 7").length === 0, "plain chat has no snippet")
assert(snippetValues("Order 123456 shipped").length === 0, "order number is not a code")
assert(snippetValues("Call +18015550100").length === 0, "phone number is not a code")
assert(snippetValues("Happy 2024").length === 0, "year is not a code")
assert(snippetValues("invoice 20240901").length === 0, "date is not a code")
assert(snippetValues("1234").length === 0, "bare 4-digit is not a code")
assert(snippetValues("javascript:alert(1)").length === 0, "javascript url is not a link")
assert(snippetValues("www.example.com/login").length === 0, "schemeless www is not a link")
assert(snippetValues("Meet at https://example.com/join.").indexOf("link:https://example.com/join") !== -1, "strips trailing period from url")
assert(snippetValues("reset at https://example.com/login").indexOf("link:https://example.com/login") !== -1, "http link copies, does not need a code")
assert(snippetValues("code 123456 https://ex.com/a").indexOf("code:123456") !== -1, "code plus link keeps the code")
assert(snippetValues("code 123456 https://ex.com/a").indexOf("link:https://ex.com/a") !== -1, "code plus link keeps the link")
assert(snippetValues("https://evil.example/login?code=123456").indexOf("code:123456") === -1, "digits inside a url are not a code")
assert(sandbox.copySnippets("https://evil.example/login?code=123456")[0].kind === "link", "url query becomes a copy-link")
assert(sandbox.copyLinkLabel("https://www.example.com/x") === "Copy example.com", "link label uses host")
assert(sandbox.primaryCopySnippet(sandbox.copySnippets("code 123456 https://ex.com")).value === "123456", "primary snippet prefers a code")
assert(sandbox.primaryCopySnippet(sandbox.copySnippets("https://ex.com")).kind === "link", "primary snippet falls back to link")
assert(sandbox.primaryCopySnippet([]) === null, "no snippets")
assert(sandbox.notificationCopySnippets({ title: "123456", text: "is your Google verification code" })[0].value === "123456", "notification title plus body")
assert(sandbox.messageCopySnippets({ body: "Your OTP is 246810" })[0].value === "246810", "message snippets read body")
assert(sandbox.copySnippets("Your code is 123456. Order 998877.")[0].value === "123456", "prefers the code nearest the cue")

const oldOk = { id: 1, body: "ok", fromMe: true, date: 10 }
const pendingOk = { id: -99, body: "ok", fromMe: true, date: 20, pending: true }
let merged = sandbox.mergeSmsMessages([oldOk, pendingOk], [oldOk])
assert(merged.some(function(m) { return m.pending }), "pending kept when only an older same body exists")
const echoOk = { id: 2, body: "ok", fromMe: true, date: 21 }
merged = sandbox.mergeSmsMessages([oldOk, pendingOk], [oldOk, echoOk])
assert(!merged.some(function(m) { return m.pending }), "pending drops when a new from-me echo arrives")
assert(merged.some(function(m) { return m.id === 2 }), "echo is kept")
merged = sandbox.mergeSmsMessages([pendingOk], [{ id: 5, body: "hi", fromMe: false, date: 5 }])
assert(merged.some(function(m) { return m.pending }), "pending kept without an echo")

console.log("ok")
