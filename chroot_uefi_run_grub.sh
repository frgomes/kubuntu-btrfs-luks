#!/bin/bash -euxx

function chroot_uefi_run_grub() {
  echo "[ uefi_run_grub ]"
  local device="$(cat /dev/shm/device)"
  grub-install ${device}
  update-grub
}

chroot_uefi_run_grub
