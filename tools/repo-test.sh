#!/usr/bin/env bash
# Tests that a fresh install updates from the hosted [ambrosia] repo: installs
# the newest image (out/iso/) in the test VM, boots the installed system into
# tools/repo-check.sh alone, and prints its report. Publish packages newer than
# the image's first (`make publish`), so an upgrade is tested too. Run as root
# on the build host; it erases the VM's disk.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
vm="$root/out/vm"
share="$vm/repo-check"

# Waits for the VM to power itself off.
wait_off() {
  local pid
  pid=$(cat "$vm/qemu.pid")
  for _ in $(seq 360); do kill -0 "$pid" 2>/dev/null || return 0; sleep 5; done
  echo "repo-test: the VM is still running after 30 minutes" >&2
  return 1
}

echo "Installing the newest image in the VM"
"$root/tools/vm.sh" install
wait_off

rm -rf "$share"
mkdir -p "$share"
install -m755 "$root/tools/repo-check.sh" "$share/"
# systemd-boot appends this SMBIOS string to the installed system's command
# line, and systemd boots into the command alone, then powers off.
run="mount -m -t 9p -o trans=virtio repo-check /run/repo-check && exec /run/repo-check/repo-check.sh"
echo "Booting the installed system into repo-check.sh"
"$root/tools/vm.sh" installed \
  -virtfs "local,path=$share,mount_tag=repo-check,security_model=none" \
  -smbios "type=11,value=io.systemd.boot.kernel-cmdline-extra=systemd.run=\"/usr/bin/sh -c '$run'\" systemd.run_success_action=poweroff systemd.run_failure_action=poweroff"
wait_off

cat "$share/repo-check.log"
grep -qx 'RESULT: PASS' "$share/repo-check.log"
