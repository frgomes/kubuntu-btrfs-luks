#!/bin/bash -eux

function chroot_install_btrfs_progs() {
  echo "[ install_btrfs_progs ]"
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y btrfs-progs cryptsetup snapper
}

chroot_install_btrfs_progs
