#!/bin/bash -eu

function chroot_install_btrfs_progs() {
  echo "[ install_btrfs_progs ]"
  apt update
  ##FIXME: handle retries
  apt install -y btrfs-progs cryptsetup snapper
  apt install -y btrfs-progs cryptsetup snapper
  apt install -y btrfs-progs cryptsetup snapper
}

chroot_install_btrfs_progs
