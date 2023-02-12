#!/bin/bash -eu

function chroot_uefi_run_grub() {
  echo "[ uefi_run_grub ]"
  local device="$(cat /dev/shm/device)"
  grub-install ${device}p1
  update-grub
}

chroot_uefi_run_grub
