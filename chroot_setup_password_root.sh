#!/bin/bash -eux

function chroot_setup_password_root() {
  cat /dev/shm/root_password | passwd --quiet root
}

chroot_setup_password_root
