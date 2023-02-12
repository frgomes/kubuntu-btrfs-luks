#!/bin/bash -eux

function chroot_configure_initramfs_tools() {
  echo "[ configure_initramfs_tools ]"
  ##FIXME: maybe COMPRESS=zstd
  cat <<EOD >> /etc/initramfs-tools/initramfs.conf
UMASK=0077
EOD
  cat /etc/initramfs-tools/initramfs.conf
  update-initramfs -u
  # debugging
  stat -Lc "%A %n" /initrd.img
  lsinitramfs /initrd.img | grep -E "^crypt"
}

chroot_configure_initramfs_tools
