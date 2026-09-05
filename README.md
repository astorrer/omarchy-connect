# Connect

Phone connect for the Omarchy bar. Same idea as GSConnect: the KDE Connect protocol, a native shell UI, no Plasma app.

The daemon is still `kdeconnectd` — pairing and crypto are not worth reimplementing. The bar, the panel, install, and autostart are ours.

## Install

```sh
omarchy plugin add https://github.com/astorrer/omarchy-connect.git --enable
```

Click **Install Connect** in the panel the first time. That:

- installs `kdeconnect`
- opens TCP/UDP `1714–1764` if `ufw` is active
- writes an autostart entry for `kdeconnectd`
- starts the daemon

Then open **KDE Connect** on the phone, same Wi-Fi, and pair from the panel.

## Use

- Left click: panel
- Right click: refresh
- Middle click: ping the primary phone
- In the panel: ping, ring, send clipboard, send file, pair / unpair
- Keys: `r` refresh, `p` ping, `f` ring, `c` clipboard, `s` send file, `i` install

## Why not the KDE app

Omarchy already does this for Dropbox and Tailscale: a service plus a bar widget. GSConnect worked on GNOME because it lived in the shell. Connect is that shape for Omarchy.

Remote input (phone as a touchpad) is still weak on Hyprland. File send, clipboard, ping, ring, battery, and pairing are the v1 surface.

## Develop

```sh
ln -sfn ~/Github/omarchy-connect ~/.config/omarchy/plugins/io.github.astorrer.connect
omarchy plugin enable io.github.astorrer.connect --section right
omarchy plugin validate ~/Github/omarchy-connect
python3 ~/Github/omarchy-connect/connect.py status
```
