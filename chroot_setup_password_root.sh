#!/bin/bash -eux

function chroot_setup_password_root() {
  dd if=/dev/urandom count=1 bs=32 | base64 | passwd --quiet root > /dev/null
  cat /dev/shm/root_password | passwd --quiet root
}

chroot_setup_password_root
