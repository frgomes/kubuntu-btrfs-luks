#!/bin/bash -eux

function chroot_install_grub() {
  echo "[ install_grub ]"
  local hwarch="$(cat /dev/shm/hwarch)"
  apt install -y grub-efi-${hwarch}
}

chroot_install_grub
