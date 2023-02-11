#!/bin/bash -eux

function chroot_install_grub() {
  echo "[ install_grub ]"
  ##FIXME: should detect hardware architecture
  local hwarch=amd64
  apt install -y grub-efi-${hwarch}
}

chroot_install_grub
