#!/bin/bash
# Install kdeconnect, open the discovery ports, start the daemon, and autostart it.

set -euo pipefail

echo "Installing KDE Connect..."
omarchy-pkg-add kdeconnect

DAEMON=""
for candidate in /usr/lib/kdeconnectd /usr/libexec/kdeconnectd /usr/bin/kdeconnectd; do
  if [[ -x $candidate ]]; then
    DAEMON=$candidate
    break
  fi
done

if [[ -z $DAEMON ]]; then
  echo "kdeconnect installed, but kdeconnectd was not found." >&2
  exit 1
fi

echo "Opening ports 1714-1764 (TCP/UDP) if ufw is active..."
if command -v ufw >/dev/null && sudo ufw status 2>/dev/null | grep -qi '^Status: active'; then
  sudo ufw allow 1714:1764/tcp comment 'KDE Connect' || true
  sudo ufw allow 1714:1764/udp comment 'KDE Connect' || true
else
  echo "ufw is not active; skipped firewall rules."
fi

mkdir -p "$HOME/.config/autostart"
cat > "$HOME/.config/autostart/kdeconnectd.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=KDE Connect
Comment=Phone connect daemon for Connect
Exec=$DAEMON
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

if ! pgrep -u "$USER" -x kdeconnectd >/dev/null; then
  echo "Starting kdeconnectd..."
  setsid "$DAEMON" >/dev/null 2>&1 &
fi

echo
echo "Connect is ready. Open KDE Connect on your phone, on the same Wi-Fi, and pair from the bar."
