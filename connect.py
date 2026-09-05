#!/usr/bin/python3
"""Talk to kdeconnectd over session D-Bus and print JSON for the Omarchy panel."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

BUS_NAME = "org.kde.kdeconnect"
DAEMON_PATH = "/modules/kdeconnect"
DAEMON_IFACE = "org.kde.kdeconnect.daemon"
DEVICE_IFACE = "org.kde.kdeconnect.device"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
TIMEOUT_MS = 2500

DAEMON_CANDIDATES = (
    "/usr/lib/kdeconnectd",
    "/usr/libexec/kdeconnectd",
    "/usr/bin/kdeconnectd",
)

AUTOSTART_PATH = Path.home() / ".config" / "autostart" / "kdeconnectd.desktop"

AUTOSTART_DESKTOP = """[Desktop Entry]
Type=Application
Name=KDE Connect
Comment=Phone connect daemon for Connect
Exec={daemon}
Terminal=false
X-GNOME-Autostart-enabled=true
"""


def emit(payload: dict) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def fail(message: str, **extra) -> None:
    payload = {"ok": False, "error": message}
    payload.update(extra)
    emit(payload)
    raise SystemExit(0)


def daemon_path() -> str | None:
    for path in DAEMON_CANDIDATES:
        if os.access(path, os.X_OK):
            return path
    found = shutil.which("kdeconnectd")
    return found if found and os.access(found, os.X_OK) else None


def session_bus():
    return Gio.bus_get_sync(Gio.BusType.SESSION, None)


def name_has_owner(bus, name: str) -> bool:
    try:
        result = bus.call_sync(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "NameHasOwner",
            GLib.Variant("(s)", (name,)),
            GLib.VariantType("(b)"),
            Gio.DBusCallFlags.NONE,
            TIMEOUT_MS,
            None,
        )
        return bool(result.unpack()[0])
    except GLib.Error:
        return False


def call(bus, path: str, iface: str, method: str, params: GLib.Variant | None = None):
    return bus.call_sync(
        BUS_NAME,
        path,
        iface,
        method,
        params,
        None,
        Gio.DBusCallFlags.NONE,
        TIMEOUT_MS,
        None,
    )


def get_prop(bus, path: str, iface: str, name: str, default=None):
    try:
        result = bus.call_sync(
            BUS_NAME,
            path,
            PROPS_IFACE,
            "Get",
            GLib.Variant("(ss)", (iface, name)),
            GLib.VariantType("(v)"),
            Gio.DBusCallFlags.NONE,
            TIMEOUT_MS,
            None,
        )
        return result.unpack()[0]
    except GLib.Error:
        return default


def try_call(bus, path: str, iface: str, methods: list[tuple[str, GLib.Variant | None]]):
    last_error = None
    for method, params in methods:
        try:
            return call(bus, path, iface, method, params)
        except GLib.Error as error:
            last_error = error
            continue
    if last_error:
        raise last_error
    raise RuntimeError("no methods to call")


def device_ids(bus) -> list[str]:
    result = try_call(
        bus,
        DAEMON_PATH,
        DAEMON_IFACE,
        [
            ("devices", GLib.Variant("(b)", (False,))),
            ("devices", None),
        ],
    )
    ids = result.unpack()[0] if result.n_children() else []
    return [str(item) for item in ids]


def device_path(device_id: str) -> str:
    return f"{DAEMON_PATH}/devices/{device_id}"


def plugin_path(device_id: str, plugin: str) -> str:
    return f"{device_path(device_id)}/{plugin}"


def read_device(bus, device_id: str) -> dict:
    path = device_path(device_id)
    plugins = get_prop(bus, path, DEVICE_IFACE, "loadedPlugins", []) or []
    plugins = [str(item).split(".")[-1] for item in plugins]
    battery = -1
    charging = False
    if "battery" in plugins or True:
        charge = get_prop(bus, plugin_path(device_id, "battery"), "org.kde.kdeconnect.device.battery", "charge", None)
        charging_val = get_prop(
            bus,
            plugin_path(device_id, "battery"),
            "org.kde.kdeconnect.device.battery",
            "isCharging",
            None,
        )
        if isinstance(charge, int):
            battery = charge
        if isinstance(charging_val, bool):
            charging = charging_val
    network_type = get_prop(
        bus,
        plugin_path(device_id, "connectivity_report"),
        "org.kde.kdeconnect.device.connectivity_report",
        "cellularNetworkType",
        "",
    )
    network_strength = get_prop(
        bus,
        plugin_path(device_id, "connectivity_report"),
        "org.kde.kdeconnect.device.connectivity_report",
        "cellularNetworkStrength",
        -1,
    )
    return {
        "id": device_id,
        "name": str(get_prop(bus, path, DEVICE_IFACE, "name", device_id) or device_id),
        "type": str(get_prop(bus, path, DEVICE_IFACE, "type", "") or ""),
        "reachable": bool(get_prop(bus, path, DEVICE_IFACE, "isReachable", False)),
        "paired": bool(get_prop(bus, path, DEVICE_IFACE, "isPaired", False)),
        "pairRequested": bool(get_prop(bus, path, DEVICE_IFACE, "isPairRequested", False)),
        "pairRequestedByPeer": bool(get_prop(bus, path, DEVICE_IFACE, "isPairRequestedByPeer", False)),
        "battery": battery,
        "charging": charging,
        "networkType": str(network_type or ""),
        "networkStrength": int(network_strength) if isinstance(network_strength, int) else -1,
        "plugins": plugins,
    }


def sort_devices(devices: list[dict]) -> list[dict]:
    def key(device: dict):
        return (
            0 if device.get("reachable") and device.get("paired") else 1,
            0 if device.get("pairRequestedByPeer") else 1,
            0 if device.get("reachable") else 1,
            str(device.get("name") or "").lower(),
        )

    return sorted(devices, key=key)


def status_payload() -> dict:
    path = daemon_path()
    installed = path is not None
    bus = session_bus()
    running = name_has_owner(bus, BUS_NAME)
    payload = {
        "ok": True,
        "installed": installed,
        "running": running,
        "daemonPath": path or "",
        "announcedName": "",
        "devices": [],
        "error": "",
    }
    if not running:
        return payload
    try:
        payload["announcedName"] = str(get_prop(bus, DAEMON_PATH, DAEMON_IFACE, "announcedName", "") or "")
        if not payload["announcedName"]:
            try:
                result = call(bus, DAEMON_PATH, DAEMON_IFACE, "announcedName", None)
                payload["announcedName"] = str(result.unpack()[0])
            except GLib.Error:
                pass
        payload["devices"] = sort_devices([read_device(bus, device_id) for device_id in device_ids(bus)])
    except GLib.Error as error:
        payload["error"] = str(error.message)
    return payload


def require_device(device_id: str) -> tuple:
    if not device_id:
        fail("Missing device id")
    bus = session_bus()
    if not name_has_owner(bus, BUS_NAME):
        fail("KDE Connect is not running")
    return bus, device_id


def cmd_status(_args: list[str]) -> None:
    emit(status_payload())


def cmd_start(_args: list[str]) -> None:
    path = daemon_path()
    if not path:
        fail("kdeconnect is not installed")
    bus = session_bus()
    if name_has_owner(bus, BUS_NAME):
        emit({"ok": True, "running": True})
        return
    subprocess.Popen(
        [path],
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    emit({"ok": True, "running": True, "started": True})


def cmd_stop(_args: list[str]) -> None:
    bus = session_bus()
    if not name_has_owner(bus, BUS_NAME):
        emit({"ok": True, "running": False})
        return
    try:
        call(bus, "/MainApplication", "org.qtproject.Qt.QCoreApplication", "quit", None)
    except GLib.Error:
        subprocess.run(["pkill", "-u", str(os.getuid()), "-x", "kdeconnectd"], check=False)
    emit({"ok": True, "running": False})


def cmd_ping(args: list[str]) -> None:
    bus, device_id = require_device(args[0] if args else "")
    try_call(
        bus,
        plugin_path(device_id, "ping"),
        "org.kde.kdeconnect.device.ping",
        [("sendPing", None), ("sendPing", GLib.Variant("(s)", ("Ping from Connect",)))],
    )
    emit({"ok": True})


def cmd_ring(args: list[str]) -> None:
    bus, device_id = require_device(args[0] if args else "")
    try_call(
        bus,
        plugin_path(device_id, "findmyphone"),
        "org.kde.kdeconnect.device.findmyphone",
        [("ring", None)],
    )
    emit({"ok": True})


def cmd_pair(args: list[str]) -> None:
    bus, device_id = require_device(args[0] if args else "")
    try_call(
        bus,
        device_path(device_id),
        DEVICE_IFACE,
        [("requestPairing", None), ("requestPair", None)],
    )
    emit({"ok": True})


def cmd_unpair(args: list[str]) -> None:
    bus, device_id = require_device(args[0] if args else "")
    call(bus, device_path(device_id), DEVICE_IFACE, "unpair", None)
    emit({"ok": True})


def cmd_accept(args: list[str]) -> None:
    bus, device_id = require_device(args[0] if args else "")
    try_call(
        bus,
        device_path(device_id),
        DEVICE_IFACE,
        [("acceptPairing", None), ("acceptPairingRequest", None)],
    )
    emit({"ok": True})


def cmd_reject(args: list[str]) -> None:
    bus, device_id = require_device(args[0] if args else "")
    try_call(
        bus,
        device_path(device_id),
        DEVICE_IFACE,
        [("rejectPairing", None), ("rejectPairingRequest", None)],
    )
    emit({"ok": True})


def cmd_share_file(args: list[str]) -> None:
    if len(args) < 2:
        fail("Usage: share-file <device-id> <path>")
    bus, device_id = require_device(args[0])
    path = Path(args[1]).expanduser().resolve()
    if not path.exists():
        fail(f"File not found: {path}")
    uri = path.as_uri()
    call(
        bus,
        plugin_path(device_id, "share"),
        "org.kde.kdeconnect.device.share",
        "shareUrl",
        GLib.Variant("(s)", (uri,)),
    )
    emit({"ok": True, "uri": uri})


def cmd_share_text(args: list[str]) -> None:
    if len(args) < 2:
        fail("Usage: share-text <device-id> <text>")
    bus, device_id = require_device(args[0])
    text = " ".join(args[1:])
    call(
        bus,
        plugin_path(device_id, "share"),
        "org.kde.kdeconnect.device.share",
        "shareText",
        GLib.Variant("(s)", (text,)),
    )
    emit({"ok": True})


def cmd_send_clipboard(args: list[str]) -> None:
    bus, device_id = require_device(args[0] if args else "")
    try:
        try_call(
            bus,
            plugin_path(device_id, "clipboard"),
            "org.kde.kdeconnect.device.clipboard",
            [("sendClipboard", None)],
        )
    except GLib.Error:
        clip = subprocess.run(["wl-paste", "--no-newline"], capture_output=True, text=True, check=False)
        text = clip.stdout if clip.returncode == 0 else ""
        if not text:
            fail("Clipboard is empty")
        cmd_share_text([device_id, text])
        return
    emit({"ok": True})


def cmd_autostart(_args: list[str]) -> None:
    path = daemon_path()
    if not path:
        fail("kdeconnect is not installed")
    AUTOSTART_PATH.parent.mkdir(parents=True, exist_ok=True)
    AUTOSTART_PATH.write_text(AUTOSTART_DESKTOP.format(daemon=path), encoding="utf-8")
    emit({"ok": True, "path": str(AUTOSTART_PATH)})


COMMANDS = {
    "status": cmd_status,
    "start": cmd_start,
    "stop": cmd_stop,
    "ping": cmd_ping,
    "ring": cmd_ring,
    "pair": cmd_pair,
    "unpair": cmd_unpair,
    "accept": cmd_accept,
    "reject": cmd_reject,
    "share-file": cmd_share_file,
    "share-text": cmd_share_text,
    "send-clipboard": cmd_send_clipboard,
    "autostart": cmd_autostart,
}


def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        sys.stderr.write("Usage: connect.py <command> [args...]\n")
        sys.stderr.write("Commands: " + ", ".join(COMMANDS) + "\n")
        raise SystemExit(2)
    command = sys.argv[1]
    handler = COMMANDS.get(command)
    if handler is None:
        fail(f"Unknown command: {command}")
    try:
        handler(sys.argv[2:])
    except GLib.Error as error:
        fail(error.message)


if __name__ == "__main__":
    main()
