#!/bin/bash -eux

function chroot_setup_password_user() {
  local fullname=$(cat /dev/shm/user_fullname)
  local username=$(cat /dev/shm/user_username)
  useradd -m "${username}" -c "${fullname}"
  cat /dev/shm/user_password | passwd --quiet "${username}"
}

chroot_setup_password_user
