#!/bin/bash -eux

source ./functions_bootstrap.sh
source ./functions_chroot.sh

function define_filesystems() {
  echo "[ make_filesystems ]"
  local device=$(cat /dev/shm/device)
  local partition=${device}p
  local passphrase=$(cat /dev/shm/luks_passphrase)
  echo -n "${passphrase}" | cryptsetup luksOpen   -d -              ${partition}2 cryptswap
  echo -n "${passphrase}" | cryptsetup luksOpen   -d -              ${partition}4 cryptroot
  lsblk
}

# define_filesystems
# read -p "Press ENTER"
#
# mount_volumes
# read -p "Press ENTER"
#
# setup_chroot
# read -p "Press ENTER"
#
# deploy_chroot_scripts
# read -p "Press ENTER"
#
# chroot_install_grub
# read -p "Press ENTER"
#
# chroot_kernel_update
# read -p "Press ENTER"






chroot_install_grub
read -p "Press ENTER"
update-brub
