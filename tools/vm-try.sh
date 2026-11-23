#!/bin/bash
# A throwaway copy of the test install, to try what can keep someone out of
# their session (the lock screen, the login screen) where the password is
# known: user `test`, password `ambrosia`. Run on tenet, as root.
#
#   tools/vm-try.sh up             boot an overlay of out/vm/fresh.qcow2, small and at low
#                                  priority, with root SSH (systemd credentials); wait a minute
#   tools/vm-try.sh ssh '<cmd>'    run a command in it as root
#   tools/vm-try.sh push <src> <dst>   copy a file or folder into it
#   tools/vm-try.sh type 'text'    type at its keyboard (a-z, 0-9, space, - . /)
#   tools/vm-try.sh key ret ...    press keys (QEMU sendkey names)
#   tools/vm-try.sh shot <name>    photograph its screen into /var/tmp/vm-try/<name>.png
#   tools/vm-try.sh stop           power it off and delete the overlay
#
# The install it copies is never written to. Needs the Packaging lane's VM
# key (/var/tmp/ambrosia-packaging/vmkey) and 5 GB of memory to spare.
set -eu
D=/var/tmp/vm-try
root=$(cd "$(dirname "$0")/.." && pwd)
key=/var/tmp/ambrosia-packaging/vmkey
opts=(-q -i "$key" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8)
hmp() { printf '%s\n' "$*" | socat - "UNIX-CONNECT:$D/monitor.sock" >/dev/null; }
cmd=${1:?usage: tools/vm-try.sh up|ssh|push|type|key|shot|stop}
shift
case $cmd in
up)
  mkdir -p $D
  [ ! -S $D/monitor.sock ] || { echo "vm-try: already up (tools/vm-try.sh stop)" >&2; exit 1; }
  avail=$(free -m | awk '/Mem:/{print $7}')
  [ "$avail" -ge 5000 ] || { echo "vm-try: only $avail MB available" >&2; exit 1; }
  qemu-img create -q -f qcow2 -b "$root/out/vm/fresh.qcow2" -F qcow2 $D/disk.qcow2
  cp "$root/out/vm/vars-fresh.fd" $D/vars.fd
  keys=$(base64 -w0 < "$key.pub")
  unit=$(base64 -w0 <<'UNIT'
[Unit]
Description=Test access: sshd
Wants=network-online.target
After=network-online.target
ConditionPathExists=!/etc/initrd-release
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'for i in 1 2 3 4 5 6; do command -v sshd >/dev/null && break; pacman -Sy --noconfirm --needed openssh && break; sleep 10; done; systemctl start sshd'
UNIT
)
  dropin=$(printf '[Unit]\nWants=vm-access.service\n' | base64 -w0)
  nice -n 19 ionice -c3 qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 2 -m 3G \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
    -drive if=pflash,format=raw,file=$D/vars.fd \
    -drive file=$D/disk.qcow2,if=virtio,format=qcow2 \
    -device virtio-vga,xres=1920,yres=1200 -display none \
    -nic user,model=virtio-net-pci,hostfwd=tcp::10022-:22 \
    -monitor unix:$D/monitor.sock,server,nowait -daemonize -pidfile $D/qemu.pid \
    -smbios "type=11,value=io.systemd.credential.binary:ssh.authorized_keys.root=$keys" \
    -smbios "type=11,value=io.systemd.credential.binary:systemd.extra-unit.vm-access.service=$unit" \
    -smbios "type=11,value=io.systemd.credential.binary:systemd.unit-dropin.multi-user.target=$dropin"
  echo "vm-try: started; the login screen is up in about a minute" ;;
ssh) ssh "${opts[@]}" -p 10022 root@localhost "$@" ;;
push) scp "${opts[@]}" -P 10022 -r "$1" "root@localhost:$2" ;;
type)
  text=$1
  for ((i = 0; i < ${#text}; i++)); do
    c=${text:i:1}
    case $c in
    [a-z0-9]) k=$c ;; [A-Z]) k=shift-${c,,} ;; ' ') k=spc ;; -) k=minus ;; .) k=dot ;; /) k=slash ;;
    *) echo "vm-try: no key for '$c'" >&2; exit 1 ;;
    esac
    hmp sendkey "$k"; sleep 0.08
  done ;;
key) for k in "$@"; do hmp sendkey "$k"; sleep 0.15; done ;;
shot) hmp "screendump $D/$1.png -f png"; sleep 0.6; echo "$D/$1.png" ;;
stop)
  pkill -F $D/qemu.pid 2>/dev/null || true
  sleep 2
  rm -rf $D
  echo "vm-try: stopped, overlay deleted" ;;
*) echo "vm-try: up|ssh|push|type|key|shot|stop" >&2; exit 1 ;;
esac
