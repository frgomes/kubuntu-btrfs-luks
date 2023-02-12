#!/bin/bash -eux

function chroot_create_fstab() {
  echo "[ create_fstab ]"
  local device="$(cat /dev/shm/device)"
  local partition="${device}"p
  local uuid_efi=$(blkid  | fgrep ${partition}1 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_swap=$(blkid | fgrep ${partition}2 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_boot=$(blkid | fgrep ${partition}3 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_root=$(blkid | fgrep ${partition}4 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  cat /proc/mounts | grep -v -E '^tmpfs' | grep -E "^/dev/mapper/|^${partition}" | \
    sed -E "s|^/dev/mapper/cryptroot|${uuid_root}|" | \
    sed -E "s|${partition}1|${uuid_efi}|" | \
    sed -E "s|^${partition}3|${uuid_boot}|" | \
    sed -E "s|/ btrfs|/           btrfs|" | \
    sed -E "s|/home btrfs|/home       btrfs|" | \
    sed -E "s|/@ 0 0|/           0 0|" | \
    sed -E "s|/@home 0 0|/home       0 0|" > /etc/fstab
  # debugging
  cat /etc/fstab
}

chroot_create_fstab
