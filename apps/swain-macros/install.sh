#!/usr/bin/env bash
# One-time setup: dependencies, mouse permissions, and the app launcher. Run as your normal user.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ID=local.guibs.SwainMacros
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"

if [[ $EUID -eq 0 ]]; then
  echo "Run this as your normal user (it asks for sudo only when needed)." >&2
  exit 1
fi

echo "==> Checking dependencies"
PKGS=(python3-evdev python3-gi gir1.2-gtk-4.0 gir1.2-adw-1)
if ! dpkg -s "${PKGS[@]}" >/dev/null 2>&1; then
  sudo apt-get install -y "${PKGS[@]}"
fi

echo "==> Allowing your user to use the mouse and create virtual input devices (sudo)"
sudo install -m 644 "$DIR/data/70-swain-macros.rules" /etc/udev/rules.d/70-swain-macros.rules
echo uinput | sudo tee /etc/modules-load.d/swain-macros.conf >/dev/null
sudo modprobe uinput
sudo udevadm control --reload-rules
sudo udevadm trigger --action=change --subsystem-match=misc --sysname-match=uinput
sudo udevadm trigger --action=change --subsystem-match=input --property-match=ID_VENDOR_ID=04d9
sudo udevadm settle

echo "==> Adding Swain Macros to the app menu"
chmod +x "$DIR/swain-macros"
mkdir -p "$DATA/applications" "$DATA/icons/hicolor/256x256/apps"
install -m 644 "$DIR/data/$APP_ID.png" "$DATA/icons/hicolor/256x256/apps/$APP_ID.png"
sed "s|@EXEC@|\"$DIR/swain-macros\"|" "$DIR/data/$APP_ID.desktop" > "$DATA/applications/$APP_ID.desktop"
update-desktop-database "$DATA/applications" 2>/dev/null || true

echo
echo "Done! Open “Swain Macros” from the app menu."
