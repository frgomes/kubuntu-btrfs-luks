#!/bin/bash -eu

function chroot_install_btrfs_progs() {
  echo "[ install_btrfs_progs ]"
  apt update
  ##FIXME: handle retries
  DEBIAN_FRONTEND=noninteractive apt install -y btrfs-progs cryptsetup snapper
}

chroot_install_btrfs_progs
