#!/bin/bash -eux

function chroot_install_kernel() {
  echo "[ install_kernel ]"
  local hwarch=$(cat /dev/shm/hwarch)
  apt install -y linux-image-${hwarch} intel-microcode ${hwarch}-microcode sudo network-manager
}

chroot_install_kernel
