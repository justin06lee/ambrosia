#!/usr/bin/env sh
# Runs a command in Ambrosia's checkout on the Arch build host (tenet), e.g.
# `tools/remote.sh justin06lee@192.168.1.172 make package`. The checkout is a
# real git clone there (~/work/ambrosia, from the bare repo ~/git/ambrosia.git):
# this pushes HEAD to it and checks that out, then copies over any uncommitted
# changes, so the command sees exactly this working tree. Heavy commands
# belong under a cap there (see CONTEXT.md): tenet has no swap.
# AMBROSIA_RSH is the transport (default: ssh with the Mac's tenet key);
# AMBROSIA_REMOTE_DIR the checkout, relative to the remote home.
set -eu
host=${1:?usage: tools/remote.sh user@host [command...]}
shift
root=$(cd "$(dirname "$0")/.." && pwd)
rsh=${AMBROSIA_RSH:-ssh -i $HOME/.ssh/id_ed25519_justin -o IdentitiesOnly=yes}
dir=${AMBROSIA_REMOTE_DIR:-work/ambrosia}
# Each checkout its own ref, so two at once (one per lane) can't take each
# other's tree: remote for the default, remote-work-ambrosia-x for work/ambrosia-x.
ref=remote
[ "$dir" = work/ambrosia ] || ref=remote-$(printf %s "$dir" | tr / -)

GIT_SSH_COMMAND=$rsh git -C "$root" push -q --force "$host:git/ambrosia.git" HEAD:refs/heads/$ref
$rsh "$host" "[ -d ~/$dir/.git ] || git clone -q ~/git/ambrosia.git ~/$dir; cd ~/$dir && git fetch -q origin $ref && git reset -q --hard FETCH_HEAD && git clean -fdq" </dev/null
# Uncommitted work rides on top (ruri's own notes don't count).
if [ -n "$(git -C "$root" status --porcelain -- . ':(exclude).ruri')" ]; then
  rsync -az --delete -e "$rsh" --exclude .git --exclude /.ruri --exclude node_modules \
    --exclude /dist --exclude /out --exclude /scratch "$root/" "$host:$dir/" || {
    # 23: some files' attributes not set: the Mac's rsync can't set a
    # symlink's mode on Linux (iso/airootfs), which changes nothing.
    rc=$?; [ $rc -eq 23 ] || exit $rc; }
fi
[ $# -eq 0 ] || $rsh "$host" "cd ~/$dir && $*" </dev/null
