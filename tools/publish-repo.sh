#!/usr/bin/env bash
# Publishes Ambrosia's packages to its pacman repo, from this Mac: builds them
# on the Arch build host, signs them here, and uploads them to the rolling
# `repo` release of github.com/justin06lee/ambrosia-packages, which installed
# systems use as [ambrosia] (packaging/keyring/ambrosia-mirrorlist).
#
#   tools/publish-repo.sh [user@host]     (default tenet, justin06lee@192.168.1.172;
#                                         or `make publish`)
#
# Every run publishes new ambrosia-* packages from the checkout. Our Quickshell
# is rebuilt only when the release doesn't have the version in
# packaging/quickshell/PKGBUILD yet: bump its pkgrel to rebuild it.
#
# The private key never leaves this Mac: it lives in $AMBROSIA_GNUPGHOME
# (default ~/.config/ambrosia/gnupg), backed up in
# /Volumes/T7/Backups/ambrosia-signing. It builds in the build host's checkout
# (~/work/ambrosia, through tools/remote.sh); AMBROSIA_RSH and
# AMBROSIA_REMOTE_DIR change the transport and the checkout, as for remote.sh.
set -euo pipefail

host=${1:-justin06lee@192.168.1.172}
root=$(cd "$(dirname "$0")/.." && pwd)
rsh=${AMBROSIA_RSH:-ssh -i $HOME/.ssh/id_ed25519_justin -o IdentitiesOnly=yes}
dir=${AMBROSIA_REMOTE_DIR:-work/ambrosia}
release=(-R justin06lee/ambrosia-packages)
tag=repo
key=2DB46FDF911241FC9406002BCF43580DA0F59EB8
export GNUPGHOME=${AMBROSIA_GNUPGHOME:-$HOME/.config/ambrosia/gnupg}
stage="$root/out/publish"

die() { echo "publish-repo: $*" >&2; exit 1; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }
remote() { $rsh "$host" "$*" </dev/null; }

gpg --list-secret-keys "$key" >/dev/null 2>&1 || die "no signing key $key in $GNUPGHOME"
gh release view "$tag" "${release[@]}" >/dev/null 2>&1 ||
  gh release create "$tag" "${release[@]}" --title "Ambrosia packages" \
    --notes "Ambrosia's pacman repository. Its assets are replaced every time packages are published." >/dev/null
assets=$(gh release view "$tag" "${release[@]}" --json assets --jq '.assets[].name')

qs="quickshell-$(sed -n 's/^pkgver=//p' "$root/packaging/quickshell/PKGBUILD")-$(sed -n 's/^pkgrel=//p' "$root/packaging/quickshell/PKGBUILD")-x86_64.pkg.tar.zst"
# Capped: tenet also runs other projects' services and has no swap, and an
# uncapped C++ build (ninja's default 18 jobs) starved it on 2026-10-21.
cap="systemd-run --user --scope --quiet -p MemoryMax=6G nice -n 19 ionice -c3 env MAKEFLAGS=-j2 CMAKE_BUILD_PARALLEL_LEVEL=2"
build="$cap make package"
# Quickshell is built when the release lacks its version, unless the host
# already has that build in out/pkg (bump pkgrel for a new one).
if ! grep -qxF "$qs" <<<"$assets"; then
  remote "test -f ~/$dir/out/pkg/$qs" || build="$cap make quickshell && $build"
  publish_qs=1
fi

step "Building on $host: $build"
"$root/tools/remote.sh" "$host" "$build"

rm -rf "$stage"
mkdir -p "$stage/pkg" "$stage/repo"
rsync -a -e "$rsh" "$host:$dir/out/pkg/" "$stage/pkg/"
cd "$stage/pkg"
packages=(ambrosia-*.pkg.tar.zst)
[[ -n "${publish_qs:-}" ]] && packages+=("$qs")
for f in "${packages[@]}"; do
  [[ -f "$f" ]] || die "the build didn't make $f"
  # GitHub renames assets with other characters (an epoch's ':' becomes '.'),
  # and pacman would then ask for a file the release doesn't have.
  [[ "$f" =~ ^[A-Za-z0-9._-]+$ ]] || die "$f: release asset names can't hold that (no epochs)"
done

step "Adding ${#packages[@]} packages to the repo database"
# The current database comes from the release, checked against our key first.
if grep -qxF ambrosia.db <<<"$assets"; then
  gh release download "$tag" "${release[@]}" -D "$stage/repo" -p 'ambrosia.db' -p 'ambrosia.db.sig' -p 'ambrosia.files' -p 'ambrosia.files.sig'
  for db in db files; do
    gpg --verify "$stage/repo/ambrosia.$db.sig" "$stage/repo/ambrosia.$db" 2>/dev/null || die "ambrosia.$db on the release isn't signed by $key"
    mv "$stage/repo/ambrosia.$db" "$stage/repo/ambrosia.$db.tar.gz"
    rm "$stage/repo/ambrosia.$db.sig"
  done
fi
# repo-add is pacman's, so it runs on the build host, next to the packages.
remote "rm -rf ~/$dir/out/repo && mkdir -p ~/$dir/out/repo"
rsync -a -e "$rsh" "$stage/repo/" "$host:$dir/out/repo/"
remote "cd ~/$dir/out/repo && repo-add -q ambrosia.db.tar.gz ${packages[*]/#/../pkg/}"
rsync -a -e "$rsh" "$host:$dir/out/repo/" "$stage/repo/"

step "Signing with $key"
cd "$stage/repo"
# Release assets can't be symlinks: ambrosia.db and .files are real copies.
mv ambrosia.db.tar.gz ambrosia.db
mv ambrosia.files.tar.gz ambrosia.files
for f in ambrosia.db ambrosia.files "${packages[@]/#/../pkg/}"; do
  gpg --batch --yes --detach-sign --no-armor -u "$key" -o "$f.sig" "$f"
done

step "Uploading to $tag"
cd "$stage/pkg"
uploads=()
for f in "${packages[@]}"; do uploads+=("$f" "$f.sig"); done
gh release upload "$tag" "${release[@]}" --clobber "${uploads[@]}"
# The database last, so it never lists a package the release doesn't have yet.
cd "$stage/repo"
gh release upload "$tag" "${release[@]}" --clobber ambrosia.db ambrosia.db.sig ambrosia.files ambrosia.files.sig

# Drop what the database no longer lists (the versions just replaced).
keep=$(tar -xOf ambrosia.db '*/desc' | awk '/^%FILENAME%$/ { getline; print; print $0 ".sig" }')
for asset in $(gh release view "$tag" "${release[@]}" --json assets --jq '.assets[].name'); do
  case "$asset" in ambrosia.db | ambrosia.db.sig | ambrosia.files | ambrosia.files.sig) continue ;; esac
  grep -qxF "$asset" <<<"$keep" || gh release delete-asset "$tag" "$asset" "${release[@]}" -y
done

step "Published"
tar -xOf ambrosia.db '*/desc' | awk '/^%NAME%$/ { getline; n = $0 } /^%VERSION%$/ { getline; print "  " n " " $0 }'
