#!/bin/bash
# Install kdeconnect, open the discovery ports, start the daemon, and autostart it.
# `setup.sh uninstall` only undoes Konnectarchy-owned files. It does not remove kdeconnect.

set -euo pipefail

AUTOSTART="$HOME/.config/autostart/kdeconnectd.desktop"
AUTOSTART_MARK="Phone connect daemon for Konnectarchy"

uninstall() {
  if [[ -f $AUTOSTART ]] && grep -q "$AUTOSTART_MARK" "$AUTOSTART"; then
    rm -f "$AUTOSTART"
    echo "Removed $AUTOSTART"
  else
    echo "No Konnectarchy autostart entry found."
  fi
  echo
  echo "Left in place (shared, or yours to decide):"
  echo "  - the kdeconnect package"
  echo "  - ufw rules for 1714-1764, if they were added"
  echo "  - ~/.local/share/kpeoplevcard/kdeconnect-* (synced contacts)"
  echo
  echo "Remove the plugin with:"
  echo "  omarchy plugin remove io.github.astorrer.connect"
}

if [[ ${1:-} == uninstall ]]; then
  uninstall
  exit 0
fi

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
cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=KDE Connect
Comment=$AUTOSTART_MARK
Exec=$DAEMON
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

if ! pgrep -u "$USER" -x kdeconnectd >/dev/null; then
  echo "Starting kdeconnectd..."
  setsid "$DAEMON" >/dev/null 2>&1 &
fi

echo
echo "Konnectarchy is ready. Open KDE Connect on the phone, on the same Wi-Fi, and pair from the bar."
