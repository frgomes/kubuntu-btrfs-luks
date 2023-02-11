#!/bin/bash -eux

function chroot_setup_password_root() {
  local password="$(cat /dev/shm/root_password)"
  echo "root:${password}" | chpasswd
}

chroot_setup_password_root
