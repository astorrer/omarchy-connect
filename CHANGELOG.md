# Changelog

## 1.2.7

Back, new message, and dismiss-all are framed buttons. A rule sits under the header and above the reply field.

## 1.2.6

Unpair asks Cancel / Unpair in the panel before dropping the phone. Cancel is selected first.

## 1.2.5

Sending the same text twice no longer knocks the first optimistic line off the thread. Copy chips share one component. A ping or file share in flight no longer drops the next action.

## 1.2.4

Copy a 2FA code or an http(s) link from a message or notification. Click the chip, or press `y`. Links are copied, not opened. The rest of the message stays put.

## 1.2.3

Going back to the inbox or the notification list jumps to the top, where the recent items are.

## 1.2.2

Keep a just-sent message on screen until the phone actually returns it. A refresh that lands too early no longer deletes it.

## 1.2.1

Sending a reply shows it in the thread immediately, then syncs with the phone. Reloading the thread is no longer required.

## 1.2.0

SMS threads show image thumbnails and file chips for attachments. Inbox previews say Photo or the file name when there is no text.

## 1.1.3

Up and down in the inbox and in a thread follow the highlight inside that list. The reply field stays put.

## 1.1.2

Arrow keys walk the button pad in two dimensions. Enter activates; Esc goes back.

## 1.1.1

Threads keep Inbox at the top and the reply field at the bottom. Only the messages scroll. Esc from the reply field returns to the inbox.

## 1.1.0

Control pad for notifications, messages, ping, ring, clipboard, and file share. Settings live in the panel. Hero line reports battery, notifications, and radio with a bit of personality. Footer shows the version and opens the project page.

## 1.0.0

Publish polish. Enter on a device opens the first action. Refresh reloads the open inbox. Dismiss-all sits at the bottom of the notification list. Optional bar badge for phone notifications.

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
