#!/usr/bin/env bash
# Runs inside a fresh Ambrosia install, as root (tools/repo-test.sh boots the
# VM into it): updates from the hosted [ambrosia] repo with pacman -Syu,
# installs a package from it into an empty cache, and checks that every
# Ambrosia package is the repo's, signed with its key. The report goes to
# repo-check.log beside this script; its last line is RESULT: PASS or FAIL.
set -uo pipefail

exec >"$(dirname "$0")/repo-check.log" 2>&1
key=2DB46FDF911241FC9406002BCF43580DA0F59EB8
ours=(ambrosia-keyring ambrosia-theme ambrosia-shell ambrosia-desktop quickshell)
failures=()
fail() { failures+=("$*"); echo "FAIL: $*"; }
section() { printf '\n== %s\n' "$*"; }

section "Ambrosia repo check, $(date -u '+%F %T UTC'), $(uname -r)"
systemctl start NetworkManager
nm-online -q -t 120 || fail "no network"

section "[ambrosia] in /etc/pacman.conf"
sed -n '/^\[ambrosia\]$/,/^$/p' /etc/pacman.conf
grep -v '^#' /etc/pacman.d/ambrosia-mirrorlist
[[ $(grep -m1 '^\[' <(grep -v '^\[options\]' /etc/pacman.conf)) == "[ambrosia]" ]] || fail "[ambrosia] isn't the first repo"

section "The signing key in pacman's keyring"
pacman-key --list-keys "$key" || fail "pacman doesn't have the key"
gpg --homedir /etc/pacman.d/gnupg --with-colons --list-keys "$key" 2>/dev/null | grep -q '^pub:f:' || fail "the key isn't trusted"

section "Installed before"
pacman -Q "${ours[@]}"
before=$(pacman -Q "${ours[@]}")

section "pacman -Syu"
pacman -Syu --noconfirm --noprogressbar || fail "pacman -Syu failed"

section "The database's signature"
pacman-key --verify /var/lib/pacman/sync/ambrosia.db.sig /var/lib/pacman/sync/ambrosia.db || fail "ambrosia.db's signature doesn't verify"

section "Installed after, against the repo"
pacman -Sl ambrosia
for p in "${ours[@]}"; do
  installed=$(pacman -Q "$p" | cut -d' ' -f2)
  repo=$(pacman -Sl ambrosia | awk -v p="$p" '$2 == p { print $3 }')
  echo "$p: installed $installed, repo $repo"
  [[ -n "$repo" && "$installed" == "$repo" ]] || fail "$p isn't the repo's version"
done
[[ "$before" != "$(pacman -Q "${ours[@]}")" ]] || fail "nothing was upgraded: publish packages newer than the image's"
pacman -Qi quickshell | grep -q 'quickshell-dbusmenu-source' || fail "quickshell isn't our build"

section "Install from the repo into an empty cache"
rm -rf /tmp/fresh-cache && mkdir -p /tmp/fresh-cache
pacman -S --noconfirm --noprogressbar --cachedir /tmp/fresh-cache ambrosia-theme ambrosia-keyring || fail "installing from the repo failed"
ls -l /tmp/fresh-cache

section "pacman -Syu again"
pacman -Syu --noconfirm --noprogressbar | tail -n 3

section "/etc/os-release"
cat /etc/os-release

echo
if ((${#failures[@]})); then
  printf 'RESULT: FAIL (%s)\n' "$(IFS=';'; echo "${failures[*]}")"
  exit 1
fi
echo "RESULT: PASS"
