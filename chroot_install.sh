#!/bin/bash -eux

source ./functions_chroot.sh

chroot_make_apt_sources
read -p "Press ENTER"
chroot_setup_password_root
read -p "Press ENTER"
chroot_setup_password_user
read -p "Press ENTER"
chroot_install_locales
read -p "Press ENTER"
chroot_install_missing_packages
read -p "Press ENTER"
chroot_install_kernel
read -p "Press ENTER"
chroot_create_fstab
read -p "Press ENTER"
chroot_install_grub
read -p "Press ENTER"
chroot_grub_enable_cryptodisk
read -p "Press ENTER"
chroot_configure_crypttab
read -p "Press ENTER"
chroot_configure_initramfs
read -p "Press ENTER"
chroot_configure_networking
read -p "Press ENTER"
chroot_install_opensshd
read -p "Press ENTER"
chroot_uefi_run_grub
read -p "Press ENTER"
chroot_enable_services
read -p "Press ENTER"
chroot_kernel_update
read -p "Press ENTER"
