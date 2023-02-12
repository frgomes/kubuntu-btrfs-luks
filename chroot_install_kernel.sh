#!/bin/bash -eux

function chroot_install_kernel() {
  echo "[ install_kernel ]"
  local hwarch=$(cat /dev/shm/hwarch)
  local firmware=$(apt search firmware | grep -E "^firmware-" | cut -d/ -f1 | fgrep -v microbit)
  apt install -y linux-image-${hwarch} intel-microcode ${hwarch}-microcode
}

chroot_install_kernel
