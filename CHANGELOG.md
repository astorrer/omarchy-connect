# Changelog

## 0.4.0

Notification feed from the phone's KDE Connect notifications plugin.

- List active notifications in the panel (`n`, or Notifications)
- Dismiss one (`d`) or all
- Reply when the phone exposes a reply id
- Badge the bar icon while any are waiting

Desktop popups from `kdeconnectd` still appear; this is the inbox after they vanish.

## 0.3.0

Freeze of the current phone panel: pairing, ping, ring, clipboard, file share, SMS, and contact names from synced vCards.

- Look up SMS titles from `~/.local/share/kpeoplevcard/kdeconnect-<device>/`
- Split the Python helper into `connectlib/`
- Add `./tests/run`, manifest/message tests, and GitHub Actions
- Document install, Contacts permission, and what `plugin remove` does not undo
- `setup.sh uninstall` removes only the Connect autostart file

Not in 0.3: notification feed, remote input, media.

## 0.2.5

Theme-colored SMS bubbles, keyboard list follow, newest-first threads.

## 0.2.0

SMS inbox, threads, and send.

## 0.1.0

First bar widget: pair, ping, ring, clipboard, file share.
