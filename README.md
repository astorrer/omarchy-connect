# Connect

Phone connect for the Omarchy bar. Same idea as GSConnect: the KDE Connect protocol, a native shell UI, no Plasma app.

The daemon is still `kdeconnectd`. Pairing and crypto stay there. The bar, the panel, install, and autostart are this plugin.

**0.3 freeze:** pairing, ping, ring, clipboard, send file, SMS, and contact names. Notification feed is next; remote input and media are not.

## Install

```sh
omarchy plugin add https://github.com/astorrer/omarchy-connect.git --enable
```

`plugin add` only clones this repo. It does not install packages or open ports. Click **Install Connect** in the panel (or run `setup.sh`) for that. It:

- installs `kdeconnect` (`python-gobject` is pulled in with it)
- opens TCP/UDP `1714–1764` if `ufw` is active (asks for sudo in a terminal)
- writes `~/.config/autostart/kdeconnectd.desktop`
- starts `kdeconnectd`

Then open **KDE Connect** on the phone, same Wi-Fi, and pair from the panel.

For SMS names, on the phone: KDE Connect → this computer → **Contacts**. Grant Contacts permission and accept copying the address book here.

## Use

- Left click: panel
- Right click: refresh
- Middle click: ping the primary phone
- In the panel: messages, ping, ring, send clipboard, send file, pair / unpair
- Messages: inbox, thread, reply, new SMS (`m` from the device list). Threads open on the latest message; scroll up (or Up on the first row) to load older ones. Names come from synced phone contacts; unknown numbers stay numbers.
- Keys: up/down or `j` `k` move (list follows the highlight), right/`l` open, left/`h` back, Enter activate, Esc back, Tab next panel
- Also: `r` refresh, `m` messages, `p` ping, `f` ring, `c` clipboard, `s` send file, `i` install

## Remove

```sh
omarchy plugin remove io.github.astorrer.connect
```

That only deletes the plugin. To drop the autostart entry Connect wrote:

```sh
~/.config/omarchy/plugins/io.github.astorrer.connect/setup.sh uninstall
```

Left in place on purpose: the `kdeconnect` package, any ufw rules for 1714–1764, and `~/.local/share/kpeoplevcard/kdeconnect-*`.

## Why not the KDE app

Omarchy already does this for Dropbox and Tailscale: a service plus a bar widget. GSConnect worked on GNOME because it lived in the shell. Connect is that shape for Omarchy.

## Develop

Work from a symlink so saves reload in the shell. `omarchy plugin add` clones a real checkout; do not commit symlinks.

```sh
ln -sfn ~/Github/omarchy-connect ~/.config/omarchy/plugins/io.github.astorrer.connect
omarchy plugin enable io.github.astorrer.connect --section right
./tests/run
```

Layout:

```
Panel.qml          bar widget + device list
SmsView.qml        inbox / thread / compose
Service.qml        Process queue; calls connect.py
connect.py         CLI entry
connectlib/        dbus, daemon, devices, sms, contacts, messages
setup.sh           install kdeconnect (uninstall subcommand too)
```

Keep `main` installable. `omarchy plugin update` fast-forwards `origin/HEAD`.
