#!/bin/bash -eux

function chroot_setup_password_root() {
  local password="$(cat /dev/shm/root_password)"
  echo "${password}\n${password}" | passwd --quiet root
}

chroot_setup_password_root
