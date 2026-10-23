#!/usr/bin/env bash
# Build the router live ISO. Run on an Arch Linux machine (or Arch container) as root.
# Usage: sudo ./build.sh "MyRouter"
# Arch's `linux` package tracks the newest stable kernel, so the ISO gets 7.1+ once Arch ships it.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root"; exit 1; }
NAME="${1:-RouterOS}"
SAFE=$(echo "$NAME" | tr -cd 'A-Za-z0-9_-'); SAFE=${SAFE:-RouterOS}
UPPER=$(echo "$SAFE" | tr a-z A-Z | cut -c1-20)
LOWER=$(echo "$SAFE" | tr A-Z a-z)
HERE=$(cd "$(dirname "$0")" && pwd)

pacman -S --needed --noconfirm archiso
W=$(mktemp -d); P=$W/profile
cp -r /usr/share/archiso/configs/releng "$P"

sed -i "s|^iso_name=.*|iso_name=\"$LOWER\"|; s|^iso_label=.*|iso_label=\"${UPPER}_$(date +%Y%m)\"|; s|^iso_application=.*|iso_application=\"$NAME router live installer\"|; s|^iso_publisher=.*|iso_publisher=\"$NAME\"|" "$P/profiledef.sh"

printf '%s\n' dialog parted gptfdisk dosfstools e2fsprogs ntfs-3g >> "$P/packages.x86_64"

install -Dm755 "$HERE/router-install" "$P/airootfs/usr/local/bin/router-install"
echo 'file_permissions+=(["/usr/local/bin/router-install"]="0:0:755")' >> "$P/profiledef.sh"
echo "$NAME" > "$P/airootfs/etc/router-iso-name"
cat >> "$P/airootfs/root/.zlogin" <<'ZL'
[[ $(tty) == /dev/tty1 ]] && router-install
ZL

mkarchiso -v -w "$W/work" -o "$HERE/out" "$P"
echo "ISO is in $HERE/out"
