#!/bin/bash -eux

function chroot_configure_initramfs() {
  echo "[ configure_initramfs ]"
  fgrep '#KEYFILE_PATTERN=' /etc/cryptsetup-initramfs/conf-hook > /dev/null || sed 's|#KEYFILE_PATTERN=|KEYFILE_PATTERN="/boot/*.key"|' -i /etc/cryptsetup-initramfs/conf-hook
  cat /etc/cryptsetup-initramfs/conf-hook
}

chroot_configure_initramfs
