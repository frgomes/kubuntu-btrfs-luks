#!/bin/bash -eux

function chroot_install_grub() {
  echo "[ install_grub ]"
  ##FIXME: should detect hardware architecture
  local hwarch="$(cat /dev/shm/hwarch)"
  apt install -y grub-efi-${hwarch}
}

chroot_install_grub
