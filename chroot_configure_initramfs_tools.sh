#!/bin/bash -eux

function chroot_configure_initramfs_tools() {
  echo "[ configure_initramfs_tools ]"
  cat <<EOD
UMASK=0077
COMPRESS=gzip
EOD
  cat /etc/initramfs-tools/initramfs.conf
  update-initramfs -u
  # debugging
  stat -Lc "%A %n" /initrd.img
  lsinitramfs /initrd.img | grep -E "^crypt"
}

chroot_configure_initramfs_tools
