#!/bin/bash -eux

function chroot_configure_initramfs() {
  echo "[ configure_initramfs ]"
  sed -E 's|^#KEYFILE_PATTERN=[ \t]*$|KEYFILE_PATTERN="/boot/*.key"|' -i /etc/cryptsetup-initramfs/conf-hook
  echo "UMASK=0077" >> /etc/initramfs-tools/initramfs.conf

  echo "================================================================================================"
  cat /etc/cryptsetup-initramfs/conf-hook
  echo "================================================================================================"
  cat /etc/initramfs-tools/initramfs.conf
  echo "================================================================================================"

  update-initramfs -u
  stat -Lc "%A %n" /initrd.img
  lsinitramfs /initrd.img | grep -E "^crypt"
}

chroot_configure_initramfs
