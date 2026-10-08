#!/usr/bin/env bash
# Builds the Ambrosia installer image into out/iso/ from iso/ (an archiso
# profile) and the packages `make package` left in out/pkg/. Arch only, root.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
out="$root/out"
[[ $(id -u) == 0 ]] || { echo "build-iso: run as root (sudo make iso)" >&2; exit 1; }
compgen -G "$out/pkg/ambrosia-desktop-*.pkg.tar.zst" >/dev/null || { echo "build-iso: run make package first" >&2; exit 1; }

profile="$out/profile" work="$out/work"
rm -rf "$profile" "$work"
cp -a "$root/iso" "$profile"

# The packages ride on the image as a local repo: the live system and the
# installer install from it, Arch's mirrors provide the rest.
repo="$profile/airootfs/opt/ambrosia/repo"
mkdir -p "$repo"
cp "$out"/pkg/*.pkg.tar.zst "$repo/"
repo-add -q "$repo/ambrosia.db.tar.gz" "$repo"/*.pkg.tar.zst
sed "s#@REPO@#file://$repo#" "$root/iso/pacman.conf" >"$profile/pacman.conf"
sed "s#@REPO@#file:///opt/ambrosia/repo#" "$root/iso/pacman.conf" >"$profile/airootfs/etc/pacman.conf"

mkarchiso -v -r -w "$work" -o "$out/iso" "$profile"
rm -rf "$profile"
chown -R --reference="$root" "$out/iso"
