function chroot_create_volume_unlock_keys() {
  echo "[ create_volume_unlock_keys ]"
  local partition=/dev/nvme0n1p
  local passphrase="$(cat /dev/shm/luks_passphrase)"
  dd bs=1 count=512 if=/dev/urandom of=/boot/volume-swap.key
  dd bs=1 count=512 if=/dev/urandom of=/boot/volume-root.key
  echo "${passphrase}" | cryptsetup luksAddKey ${partition}2 /boot/volume-swap.key -
  echo "${passphrase}" | cryptsetup luksAddKey ${partition}4 /boot/volume-root.key -
  chmod 000 /boot/volume-swap.key
  chmod 000 /boot/volume-root.key
  chmod -R g-rwx,o-rwx /boot
}