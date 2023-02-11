#!/bin/bash -eux

##FIXME: collect parameters at startup
# passphrase
# keyboard
# language
# locales
# timezone
# hostname
# domain
# network mirror
# root passwd
# fullname
# username
# user passwd
# desktops=kde

function make_partitions() {
  echo "[ make_partitions ]"
  local drive=/dev/nvme0n1
  ##FIXME: allow configuration of swap space. Hardcoded to 16GiB at this point.
  parted -s ${drive} -- mklabel gpt
  parted -s ${drive} -- mkpart primary 1MiB 513MiB
  parted -s ${drive} -- mkpart primary 513MiB 16897MiB
  parted -s ${drive} -- mkpart primary 16897MiB 18495MiB
  parted -s ${drive} -- mkpart primary 18495MiB -64KiB
  parted -s ${drive} -- print
}

function define_luks_passphrase() {
  echo "[ define_luks_passphrase ]"
  local passphrase=passphrase
  local confirm=wrong
  while [ -z "${passphrase}" -o \( "${passphrase}" != "${confirm}" \) ] ;do
    echo -n "Enter passphrase for encrypted volume: "
    read -s passphrase
    echo ""
    echo -n "Confirm passphrase for encrypted volume: "
    read -s confirm
    echo ""
  done
  echo -n "${passphrase}" > /dev/shm/luks_passphrase
}

function make_luks() {
  echo "[ make_luks ]"
  local partition=/dev/nvme0n1p
  local passphrase="$(cat /dev/shm/luks_passphrase)"
  # swap
  echo -n "${passphrase}" | cryptsetup luksFormat --type=luks2 ${partition}2 -
  echo -n "${passphrase}" | cryptsetup luksOpen ${partition}2 cryptswap -
  # root (btrfs)
  echo -n "${passphrase}" | cryptsetup luksFormat --type=luks2 ${partition}4 -
  echo -n "${passphrase}" | cryptsetup luksOpen ${partition}4 cryptroot -
  # debugging
  lsblk
}

function make_filesystems() {
  echo "[ make_filesystems ]"
  local partition=/dev/nvme0n1p
  # efi
  mkfs.vfat ${partition}1
  # swap
  mkswap /dev/mapper/cryptswap
  # root (btrfs)
  mkfs.btrfs /dev/mapper/cryptroot
  # debugging
  lsblk
}

function make_volumes() {
  echo "[ make_volumes ]"
  mount /dev/mapper/cryptroot /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@snapshots
  umount /mnt
  lsblk
}

function mount_volumes() {
  echo "[ mount_volumes ]"
  local partition=/dev/nvme0n1p
  local options=,ssd,noatime,compress=zstd,space_cache=v2,commit=120
  # root (btrfs)
  mount -t btrfs -o ${options},subvol=@          /dev/mapper/cryptroot /mnt
  mkdir -p /mnt/home /mnt/.snapshots
  mount -t btrfs -o ${options},subvol=@home      /dev/mapper/cryptroot /mnt/home
  mount -t btrfs -o ${options},subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
  # efi
  mkdir -p /mnt/boot/efi
  mount ${partition}1 /mnt/boot/efi
  # swap
  swapon /dev/mapper/cryptswap
}

function install_debian() {
  echo "[ install_debian ]"
  local character=bullseye
  apt update
  apt install -y debootstrap
  ##FIXME: retry on network errors
  debootstrap --download-only ${character} /mnt
  debootstrap --download-only ${character} /mnt
  debootstrap --download-only ${character} /mnt
  debootstrap --download-only ${character} /mnt
  debootstrap ${character} /mnt
}

function update_sources() {
  echo "[ update_sources ]"
  local character=bullseye
  cat <<EOD > /mnt/etc/apt/sources.list
deb     http://deb.debian.org/debian ${character} main contrib non-free
deb-src http://deb.debian.org/debian ${character} main contrib non-free

deb     http://deb.debian.org/debian-security/ ${character}-security main contrib non-free
deb-src http://deb.debian.org/debian-security/ ${character}-security main contrib non-free

deb     http://deb.debian.org/debian ${character}-updates main contrib non-free
deb-src http://deb.debian.org/debian ${character}-updates main contrib non-free

### backports
# deb     http://deb.debian.org/debian ${character}-backports main contrib non-free
# deb-src http://deb.debian.org/debian ${character}-backports main contrib non-free

### unstable
# deb     http://deb.debian.org/debian/ unstable main
# deb-src http://deb.debian.org/debian/ unstable main
EOD
  # debugging
  cat /mnt/etc/apt/sources.list
}

function setup_chroot() {
  echo "[ setup_chroot ]"
  # configure chroot environment
  for dir in sys dev proc ;do mount --rbind /${dir} /mnt/${dir} && mount --make-rslave /mnt/${dir} ;done
  cp /etc/resolv.conf /mnt/etc
}

function deploy_chroot_scripts() {
  [[ -d /mnt/tmp/chroot ]] || rm -r -f /mnt/tmp/chroot
  [[ -d /mnt/tmp/kubuntu-btrfs-luks ]] || rm -r -f /mnt/tmp/kubuntu-btrfs-luks
  local dir=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
  mkdir -p /mnt/tmp
  cp -rp ${dir} /mnt/tmp
  mv /mnt/tmp/kubuntu-btrfs-luks /mnt/tmp/chroot
  echo "[ /mnt/tmp/chroot ]"
  ls /mnt/tmp/chroot
}

function umount_and_reboot() {
  echo "[ umount_and_reboot ]"
  echo "Please remove the installation media and press ENTER"
  read -s dummy
  echo "[ Installation completed successfully ]"
  sync; sync;
  reboot now
}

###  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function automated_install() {
#  make_partitions "${passphrase}"
#  echo -n "PRESS ENTER"; read -s dummy
#  define_luks_passphrase
#  echo -n "PRESS ENTER"; read -s dummy
#  make_luks
#  echo -n "PRESS ENTER"; read -s dummy
#  make_filesystems
#  echo -n "PRESS ENTER"; read -s dummy
#  make_volumes
#  echo -n "PRESS ENTER"; read -s dummy
#  mount_volumes
#  echo -n "PRESS ENTER"; read -s dummy
#  install_debian
#  echo -n "PRESS ENTER"; read -s dummy
#  update_sources
#  echo -n "PRESS ENTER"; read -s dummy


#  setup_chroot
#  echo -n "PRESS ENTER"; read -s dummy

  # deploy scripts which should run in a chroot jail
  deploy_chroot_scripts
  echo -n "PRESS ENTER"; read -s dummy

  #chroot /mnt /tmp/chroot/chroot_setup_password_root.sh
  #echo -n "PRESS ENTER"; read -s dummy
  #chroot /mnt /tmp/chroot/chroot_setup_password_user.sh
  #echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_install_locales.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_install_btrfs_progs.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_install_kernel.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_create_fstab.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_install_grub.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_grub_enable_cryptodisk.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_configure_crypttab.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_configure_initramfs.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_configure_initramfs_tools.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_configure_networking.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_install_desktops.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_install_mozilla_suite.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_install_office_suite.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_install_printer_and_scanner.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_install_utilities.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_enable_services.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_finish_installation.sh
  echo -n "PRESS ENTER"; read -s dummy

  # umount_and_reboot
}
