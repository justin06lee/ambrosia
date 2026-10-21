#!/usr/bin/env bash
# Runs the newest installer image (out/iso/) in a headless QEMU VM, for
# testing without a spare machine. State lives in out/vm/.
#
#   tools/vm.sh live          boot the image into the live desktop
#   tools/vm.sh install       erase the VM's disk and install unattended
#                             (ambrosia.autoinstall); the VM powers off when done
#   tools/vm.sh installed     boot what the VM installed (more QEMU options may follow)
#   tools/vm.sh shot out.png  screenshot the running VM
#   tools/vm.sh key ctrl-alt-f2 ...   press keys (QEMU sendkey names)
#   tools/vm.sh type 'ls ~'   type text (US layout); end with a newline to press enter
#   tools/vm.sh stop          power the VM off
# The VM's SSH port is forwarded to port 10022 on this machine (2222 is makima's).
# Needs qemu-base, qemu-hw-display-virtio-vga and -virtio-gpu (without it
# virtio-vga segfaults), edk2-ovmf and socat.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
vm="$root/out/vm"
monitor="$vm/monitor.sock"
mkdir -p "$vm"

hmp() { printf '%s\n' "$*" | socat - "UNIX-CONNECT:$monitor" >/dev/null; }
running() { [[ -S "$monitor" ]] && hmp info status 2>/dev/null; }

boot() {
  running && { echo "vm: already running (tools/vm.sh stop)" >&2; exit 1; }
  [[ -f "$vm/disk.qcow2" ]] || qemu-img create -q -f qcow2 "$vm/disk.qcow2" 40G
  [[ -f "$vm/vars.fd" ]] || cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$vm/vars.fd"
  rm -f "$monitor"
  qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 4 -m 6G \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
    -drive if=pflash,format=raw,file="$vm/vars.fd" \
    -drive file="$vm/disk.qcow2",if=virtio,format=qcow2 \
    -device virtio-vga,xres=1920,yres=1200 -display none \
    -nic user,model=virtio-net-pci,hostfwd=tcp::10022-:22 \
    -monitor unix:"$monitor",server,nowait \
    -daemonize -pidfile "$vm/qemu.pid" "$@"
}

iso() {
  local newest
  newest=$(ls -t "$root"/out/iso/*.iso 2>/dev/null | head -n1)
  [[ -n "$newest" ]] || { echo "vm: no image in out/iso (sudo make iso)" >&2; exit 1; }
  echo "$newest"
}

case "${1:-}" in
  live) boot -cdrom "$(iso)" -boot d ;;
  install)
    image=$(iso)
    rm -f "$vm/disk.qcow2" "$vm/vars.fd"
    # Boot the image's kernel directly, to add ambrosia.autoinstall.
    bsdtar -xf "$image" -C "$vm" --strip-components 3 arch/boot/x86_64/vmlinuz-linux arch/boot/x86_64/initramfs-linux.img
    boot -cdrom "$image" -kernel "$vm/vmlinuz-linux" -initrd "$vm/initramfs-linux.img" \
      -append "archisobasedir=arch archisosearchuuid=$(blkid -s UUID -o value "$image") cow_spacesize=4G ambrosia.autoinstall"
    ;;
  installed) shift; boot "$@" ;;
  shot)
    hmp "screendump $(realpath "$2") -f png"
    sleep 1
    ;;
  key) shift; for k in "$@"; do hmp "sendkey $k"; sleep 0.1; done ;;
  type)
    declare -A named=([' ']=spc [$'\n']=ret ['/']=slash ['.']=dot ['-']=minus [',']=comma [';']=semicolon
      ['=']=equal ["'"]=apostrophe ['`']=grave_accent ['\\']=backslash ['[']=bracket_left [']']=bracket_right)
    declare -A shifted=(['_']=minus ['~']=grave_accent ['|']=backslash ['>']=dot ['<']=comma [':']=semicolon
      ['"']=apostrophe ['+']=equal ['?']=slash ['!']=1 ['@']=2 ['#']=3 ['$']=4 ['%']=5 ['^']=6 ['&']=7
      ['*']=8 ['(']=9 [')']=0 ['{']=bracket_left ['}']=bracket_right)
    text=$2
    for ((i = 0; i < ${#text}; i++)); do
      c=${text:i:1}
      if [[ -n "${named[$c]:-}" ]]; then k=${named[$c]}
      elif [[ -n "${shifted[$c]:-}" ]]; then k=shift-${shifted[$c]}
      elif [[ "$c" =~ [A-Z] ]]; then k=shift-${c,,}
      else k=$c; fi
      hmp "sendkey $k"
      sleep 0.03
    done
    ;;
  stop) hmp quit || true; rm -f "$monitor" ;;
  *) sed -n '2,15p' "$0" >&2; exit 1 ;;
esac
