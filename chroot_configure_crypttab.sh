function chroot_configure_crypttab() {
  echo "[ configure_crypttab ]"
  local partition=/dev/nvme0n1p
  fgrep "${partition}" /etc/crypttab > /dev/null || cat <<EOD >> /etc/crypttab
cryptswap ${partition}2 /boot/volume-swap.key luks,discard,key-slot=1
cryptroot ${partition}4 /boot/volume-root.key luks,discard,key-slot=2
EOD
  # debugging
  cat /etc/crypttab
}