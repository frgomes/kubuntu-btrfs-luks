#!/bin/bash -eux

source ./functions_bootstrap.sh

define_arch
define_keyboard
define_language
define_timezone
define_hostname
define_domain
define_release
define_mirror
define_device
define_luks_passphrase
define_root_password
define_user_password

if [[ ! -f /dev/shm/done_step1 ]] ;then
  make_partitions
  read -p "Press ENTER"
  make_filesystems
  read -p "Press ENTER"
  make_btrfs_volumes
  read -p "Press ENTER"
  mount_volumes
  read -p "Press ENTER"
  touch /dev/shm/done_step1
fi

if [[ ! -f /dev/shm/done_step2 ]] ;then
  install_debian
  read -p "Press ENTER"
  touch /dev/shm/done_step2
fi

setup_chroot
read -p "Press ENTER"

deploy_chroot_scripts
read -p "Press ENTER"

if [[ ! -f /dev/shm/done_step3 ]] ;then
  chroot /mnt /tmp/chroot/chroot_install.sh
  read -p "Press ENTER"
  touch /dev/shm/done_step3
fi

# if [[ ! -f /dev/shm/done_step4 ]] ;then
#   chroot /mnt /tmp/chroot/chroot_kernel_update.sh
#   read -p "Press ENTER"
#   touch /dev/shm/done_step4
# fi

# if [[ ! -f /dev/shm/done_step5 ]] ;then
#   chroot /mnt /tmp/chroot/chroot_install_desktops.sh
#   read -p "Press ENTER"
#   chroot /mnt /tmp/chroot/chroot_install_mozilla_suite.sh
#   read -p "Press ENTER"
#   chroot /mnt /tmp/chroot/chroot_install_office_suite.sh
#   read -p "Press ENTER"
#   chroot /mnt /tmp/chroot/chroot_install_utilities.sh
#   read -p "Press ENTER"
#   touch /dev/shm/done_step5
# fi

##XXX if [[ ! -f /dev/shm/done_step6 ]] ;then
##XXX   chroot /mnt /tmp/chroot/chroot_install_printer_and_scanner.sh
##XXX   read -p "Press ENTER"
##XXX   chroot /mnt /tmp/chroot/chroot_finish_installation.sh
##XXX   read -p "Press ENTER"
##XXX   touch /dev/shm/done_step6
##XXX fi


echo "[ Installation completed successfully ]"
read -p "Please remove the installation media and press ENTER"
reboot now
