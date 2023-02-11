#!/bin/bash -eux

function chroot_setup_password_user() {
  local fullname=$(cat /dev/shm/user_fullname)
  local username=$(cat /dev/shm/user_username)
  useradd -m "${username}" -c "${fullname}"
  local username="$(cat /dev/shm/user_username)"
  local password="$(cat /dev/shm/user_password)"
  echo "${username}:${password}" | chpasswd
}

chroot_setup_password_user
