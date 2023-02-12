#!/bin/bash -eux

function chroot_configure_crypttab() {
  echo "[ create_volume_unlock_keys ]"
  local device=$(cat /dev/shm/device)
  local partition=${device}p
  local passphrase=$(cat /dev/shm/luks_passphrase)
  dd bs=1 count=512 if=/dev/urandom of=/boot/volume-swap.key
  dd bs=1 count=512 if=/dev/urandom of=/boot/volume-root.key
  echo -n "${passphrase}" | cryptsetup luksAddKey --key-file=- ${partition}4 /boot/volume-root.key
  echo -n "${passphrase}" | cryptsetup luksAddKey --key-file=- ${partition}2 /boot/volume-swap.key
  chmod 000 /boot/volume-root.key
  chmod 000 /boot/volume-swap.key
  chmod -R g-rwx,o-rwx /boot
  # create /etc/crypttab
  fgrep "${partition}" /etc/crypttab > /dev/null || cat <<EOD >> /etc/crypttab
cryptroot ${partition}4 /boot/volume-root.key luks,discard,key-slot=1
cryptswap ${partition}2 /boot/volume-swap.key luks,discard,key-slot=2
EOD
  # debugging
  cat /etc/crypttab
}

chroot_configure_crypttab
