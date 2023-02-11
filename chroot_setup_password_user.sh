#!/bin/bash -eux

function chroot_setup_password_user() {
  local fullname=$(cat /dev/shm/user_fullname)
  local username=$(cat /dev/shm/user_username)
  useradd -m "${username}" -c "${fullname}"
  dd if=/dev/urandom count=1 bs=32 | base64 | passwd --quiet "${username}" > /dev/null
  cat /dev/shm/user_password | passwd --quiet "${username}"
}

chroot_setup_password_user
