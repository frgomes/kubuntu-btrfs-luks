#!/bin/bash -eux

function chroot_configure_initramfs() {
  echo "[ configure_initramfs ]"
  sed -E 's|^#KEYFILE_PATTERN=[ \t]*$|KEYFILE_PATTERN="/boot/*.key"|' -i /etc/cryptsetup-initramfs/conf-hook
  cat /etc/cryptsetup-initramfs/conf-hook
}

chroot_configure_initramfs
