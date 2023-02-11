#!/bin/bash -eux

function define_keyboard() {
  echo "[ define_keyboard ]"
  if [[ ! -f /dev/shm/keyboard ]] ;then
    while
      local keyboard=US
      echo -n "Enter keyboard layout: "
      read -i "${keyboard}" keyboard
      [[ -z "${keyboard}" ]]
    do true ;done
    echo -n "${keyboard}" > /dev/shm/keyboard
  fi
}

function define_language() {
  echo "[ define_language ]"
  if [[ ! -f /dev/shm/language ]] ;then
    while
      local language=en
      echo -n "Enter language: "
      read -i "${language}" language
      [[ -z "${language}" ]]
    do true ;done
    echo -n "${language}" > /dev/shm/language
  fi
}

function define_locale() {
  echo "[ define_locale ]"
  if [[ ! -f /dev/shm/locale ]] ;then
    while
      local locale=en_US
      echo -n "Enter locale: "
      read -i "${locale}" locale
      [[ -z "${locale}" ]]
    do true ;done
    echo -n "${locale}" > /dev/shm/locale
  fi
}

function define_timezone() {
  echo "[ define_timezone ]"
  if [[ ! -f /dev/shm/timezone ]] ;then
    while
      local timezone=en_US
      echo -n "Enter timezone: "
      read -i "${timezone}" timezone
      [[ -z "${timezone}" ]]
    do true ;done
    echo -n "${timezone}" > /dev/shm/timezone
  fi
}

function define_hostname() {
  echo "[ define_hostname ]"
  if [[ ! -f /dev/shm/hostname ]] ;then
    while
      local hostname=en_US
      echo -n "Enter hostname: "
      read -i "${hostname}" hostname
      [[ -z "${hostname}" ]]
    do true ;done
    echo -n "${hostname}" > /dev/shm/hostname
  fi
}

function define_domain() {
  echo "[ define_domain ]"
  if [[ ! -f /dev/shm/domain ]] ;then
    while
      local domain=en_US
      echo -n "Enter domain: "
      read -i "${domain}" domain
      [[ -z "${domain}" ]]
    do true ;done
    echo -n "${domain}" > /dev/shm/domain
  fi
}

function define_release() {
  local release=bullseye
  echo -n "${release}" > /dev/shm/release
}

function define_mirror() {
  echo "[ define_mirror ]"
  if [[ ! -f /dev/shm/mirror ]] ;then
    while
      local mirror=en_US
      echo -n "Enter network mirror: "
      read -i "${mirror}" mirror
      [[ -z "${mirror}" ]]
    do true ;done
    echo -n "${mirror}" > /dev/shm/mirror
  fi
}

function define_device() {
  echo "[ define_device ]"
  if [[ ! -f /dev/shm/device ]] ;then
    while
      local device=/dev/nvme0n1
      echo -n "Enter installation device: "
      read -i "${device}" device
      [[ -z "${device}" ]]
    do true ;done
    echo -n "${device}" > /dev/shm/device
  fi
}

function define_luks_passphrase() {
  echo "[ define_luks_passphrase ]"
  if [[ ! -f /dev/shm/luks_passphrase ]] ;then
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
  fi
}

function define_root_password() {
  echo "[ define_root_password ]"
  if [[ ! -f /dev/shm/root_password ]] ;then
    local password=password
    local confirm=wrong
    while [ -z "${password}" -o \( "${password}" != "${confirm}" \) ] ;do
      echo -n "Enter password for root: "
      read -s password
      echo ""
      echo -n "Confirm password for root: "
      read -s confirm
      echo ""
    done
    echo -n "${password}" > /dev/shm/root_password
  fi
}

function define_user_password() {
  echo "[ define_user_password ]"
  if [[ ! -f /dev/shm/user_password ]] ;then
    local fullname=""
    while [ -z "${fullname}" ] ;do
      echo -n "Enter full name for first user: "
      read fullname
    done

    while
      local username=$(echo "${fullname}" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]' | sed -E 's/[ \t]+//g')
      echo -n "Enter username for user ${fullname}: "
      read -i "${username}" username
      [[ -z "${username}" ]]
    do true ;done

    local password=password
    local confirm=
    while [ -z "${password}" -o \( "${password}" != "${confirm}" \) ] ;do
      echo -n "Enter password for ${username}: "
      read -s password
      echo ""
      echo -n "Confirm password for ${username}: "
      read -s confirm
      echo ""
    done

    echo -n "${fullname}" > /dev/shm/user_fullname
    echo -n "${username}" > /dev/shm/user_username
    echo -n "${password}" > /dev/shm/user_password
  fi
}


function make_partitions() {
  echo "[ make_partitions ]"
  local device="$(cat /dev/shm/device)"
  ##FIXME: allow configuration of swap space. Hardcoded to 16GiB at this point.
  parted -s ${device} -- mklabel gpt
  parted -s ${device} -- mkpart primary 1MiB 513MiB
  parted -s ${device} -- mkpart primary 513MiB 16897MiB
  parted -s ${device} -- mkpart primary 16897MiB 18495MiB
  parted -s ${device} -- mkpart primary 18495MiB -64KiB
  parted -s ${device} -- print
}

function make_luks() {
  echo "[ make_luks ]"
  local device="$(cat /dev/shm/device)"
  local partition="${device}"p
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
  local device="$(cat /dev/shm/device)"
  local partition="${device}"p
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
  local device="$(cat /dev/shm/device)"
  local partition="${device}"p
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
  local release="$(cat /dev/shm/release)"
  apt update
  apt install -y debootstrap
  ##FIXME: retry on network errors
  debootstrap --download-only ${release} /mnt
  debootstrap --download-only ${release} /mnt
  debootstrap --download-only ${release} /mnt
  debootstrap --download-only ${release} /mnt
  debootstrap ${release} /mnt
}

function update_sources() {
  echo "[ update_sources ]"
  local release="$(cat /dev/shm/release)"
  cat <<EOD > /mnt/etc/apt/sources.list
deb     http://deb.debian.org/debian ${release} main contrib non-free
deb-src http://deb.debian.org/debian ${release} main contrib non-free

deb     http://deb.debian.org/debian-security/ ${release}-security main contrib non-free
deb-src http://deb.debian.org/debian-security/ ${release}-security main contrib non-free

deb     http://deb.debian.org/debian ${release}-updates main contrib non-free
deb-src http://deb.debian.org/debian ${release}-updates main contrib non-free

### backports
# deb     http://deb.debian.org/debian ${release}-backports main contrib non-free
# deb-src http://deb.debian.org/debian ${release}-backports main contrib non-free

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
  [[ -d /mnt/tmp/chroot ]] && rm -r -f /mnt/tmp/chroot
  [[ -d /mnt/tmp/kubuntu-btrfs-luks ]] && rm -r -f /mnt/tmp/kubuntu-btrfs-luks
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
  define_keyboard
  define_language
  define_locale
  define_timezone
  define_hostname
  define_domain
  define_release
  define_mirror
  define_device
  define_luks_passphrase
  define_root_password
  define_user_password

  # make_partitions "${passphrase}"
  # echo -n "PRESS ENTER"; read -s dummy
  # define_luks_passphrase
  # echo -n "PRESS ENTER"; read -s dummy
  # make_luks
  # echo -n "PRESS ENTER"; read -s dummy
  # make_filesystems
  # echo -n "PRESS ENTER"; read -s dummy
  # make_volumes
  # echo -n "PRESS ENTER"; read -s dummy
  # mount_volumes
  # echo -n "PRESS ENTER"; read -s dummy
  # install_debian
  # echo -n "PRESS ENTER"; read -s dummy
  # update_sources
  # echo -n "PRESS ENTER"; read -s dummy
  #
  # setup_chroot
  # echo -n "PRESS ENTER"; read -s dummy

  deploy_chroot_scripts
  echo -n "PRESS ENTER"; read -s dummy

  chroot /mnt /tmp/chroot/chroot_setup_password_root.sh
  echo -n "PRESS ENTER"; read -s dummy
  chroot /mnt /tmp/chroot/chroot_setup_password_user.sh
  echo -n "PRESS ENTER"; read -s dummy
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
  chroot /mnt /tmp/chroot/chroot_create_volume_unlock_keys.sh
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
