#!/bin/bash -eux

function chroot_kernel_update() {
  echo "[ kernel_update ]"
  local device="$(cat /dev/shm/device)"
  apt update
  apt upgrade
}

chroot_kernel_update
