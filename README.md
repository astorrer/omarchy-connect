# Connect

Pair a phone to the Omarchy bar over the KDE Connect protocol. Notifications, SMS, ping, ring, clipboard, and file share live in the panel. Pairing still uses `kdeconnectd`.

## Install

```sh
omarchy plugin add https://github.com/astorrer/omarchy-connect.git --enable
```

Click **Install Connect** in the panel. That installs `kdeconnect`, opens TCP/UDP `1714–1764` if `ufw` is active, and starts the daemon.

On the phone, install **KDE Connect**, join the same Wi-Fi, and pair from the panel.

For names in SMS: KDE Connect → this computer → **Contacts**. Grant permission and allow copying the address book.

## Use

- Left click opens the panel. Right click refreshes. Middle click pings the phone.
- Notifications, messages, ping, ring, clipboard, and file share are in the panel.
- Desktop popups from KDE Connect still appear. The panel keeps the ones that are still on the phone.

Keys inside the panel:

- Arrows or `j`/`k` move. The list follows the highlight.
- Enter or right/`l` activate. Left/`h` or Esc go back.
- `n` notifications · `m` messages · `d` dismiss · `p` ping · `f` ring · `c` clipboard · `s` send file · `r` refresh · `,` settings

The version in the footer opens the project page.

## Settings

Open from the gear in the panel:

- Refresh interval
- Hide the icon when no phone is reachable
- Badge the bar when the phone has notifications

## Remove

```sh
omarchy plugin remove io.github.astorrer.connect
```

That only removes the plugin. To drop the autostart file this plugin wrote:

```sh
~/.config/omarchy/plugins/io.github.astorrer.connect/setup.sh uninstall
```

The `kdeconnect` package, any ufw rules, and synced contacts stay unless you remove them yourself.
