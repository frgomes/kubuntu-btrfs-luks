#!/bin/bash -eu

function chroot_install_kernel() {
  echo "[ install_kernel ]"
  ##FIXME: should detect hardware architecture
  local hwarch=amd64
  local firmware=$(apt search firmware | grep -E "^firmware-" | cut -d/ -f1 | fgrep -v microbit)
  apt install -y linux-image-${hwarch} intel-microcode ${hwarch}-microcode firmware-linux
}

chroot_install_kernel
