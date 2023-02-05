function chroot_create_fstab() {
  echo "[ create_fstab ]"
  local partition=/dev/nvme0n1p
  local uuid_efi=$(blkid | fgrep ${partition}1 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_swap=$(blkid | fgrep ${partition}2 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_boot=$(blkid | fgrep ${partition}3 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_root=$(blkid | fgrep ${partition}4 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  cat /proc/mounts | grep -E "^/dev/mapper/|^tmpfs|^${partition}" | \
    sed -E "s|^/dev/mapper/cryptroot|${uuid_root}|" | \
    sed -E "s|^tmpfs|${uuid_root}|" | \
    sed -E "s|/ btrfs|/           btrfs|" | \
    sed -E "s|/home btrfs|/home       btrfs|" | \
    sed -E "s|/@ 0 0|/           0 0|" | \
    sed -E "s|/@home 0 0|/home       0 0|" | \
    sed -E "s|${partition}1|${uuid_efi}|" > /etc/fstab
  # debugging
  cat /etc/fstab
}
