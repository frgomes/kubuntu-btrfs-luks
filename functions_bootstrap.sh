#!/bin/bash -eux

function define_arch() {
  ##FIXME: implement this properly
  echo amd64 > /dev/shm/hwarch
}

function define_keyboard() {
  echo "[ define_keyboard ]"
  if [[ ! -f /dev/shm/keyboard ]] ;then
    while
      local keyboard=gb
      read -e -i "${keyboard}" -p "Enter keyboard layout: " keyboard
      [[ -z "${keyboard}" ]]
    do true ;done
    echo -n "${keyboard}" > /dev/shm/keyboard
  fi
}

function define_language() {
  echo "[ define_language ]"
  if [[ ! -f /dev/shm/language ]] ;then
    while
      local language=en_GB
      read -e -i "${language}" -p "Enter language: " language
      [[ -z "${language}" ]]
    do true ;done
    echo -n "${language}" > /dev/shm/language
  fi
}

function define_timezone() {
  echo "[ define_timezone ]"
  if [[ ! -f /dev/shm/timezone ]] ;then
    while
      local timezone=Etc/BST
      read -e -i "${timezone}" -p "Enter timezone: " timezone
      [[ -z "${timezone}" ]]
    do true ;done
    echo -n "${timezone}" > /dev/shm/timezone
  fi
}

function define_hostname() {
  echo "[ define_hostname ]"
  if [[ ! -f /dev/shm/hostname ]] ;then
    while
      local hostname=debian
      read -e -i "${hostname}" -p "Enter hostname: " hostname
      [[ -z "${hostname}" ]]
    do true ;done
    echo -n "${hostname}" > /dev/shm/hostname
  fi
}

function define_domain() {
  echo "[ define_domain ]"
  if [[ ! -f /dev/shm/domain ]] ;then
    while
      local domain=mathminds.io
      read -e -i "${domain}" -p "Enter domain: " domain
      [[ -z "${domain}" ]]
    do true ;done
    echo -n "${domain}" > /dev/shm/domain
  fi
}

function define_release() {
  echo "[ define_release ]"
  if [[ ! -f /dev/shm/release ]] ;then
    while
      local release=bullseye
      read -e -i "${release}" -p "Enter release: " release
      [[ -z "${release}" ]]
    do true ;done
    echo -n "${release}" > /dev/shm/release
  fi
}

function define_mirror() {
  echo "[ define_mirror ]"
  if [[ ! -f /dev/shm/mirror ]] ;then
    while
      local mirror=deb.debian.org
      read -e -i "${mirror}" -p "Enter mirror: " mirror
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
      read -e -i "${device}" -p "Enter device: " device
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
      read -e -s -p "Enter a passphrase for encrypted volume: " passphrase
      read -e -s -p "Confirm passphrase for encrypted volume: " confirm
    done
    echo -n "${passphrase}" > /dev/shm/luks_passphrase
  fi
}

function define_root_password() {
  echo "[ define_root_password ]"
  if [[ ! -f /dev/shm/root_password ]] ;then
    local username=root
    while
      read -e -s -p "Enter a password for ${username}: " password
      read -e -s -p "Confirm password for ${username}: " confirm
      [[ -z "${password}" || ( "${password}" != "${confirm}" ) ]]
    do true ;done
    echo -n "${password}" > /dev/shm/root_password
  fi
}

function define_user_password() {
  echo "[ define_user_password ]"
  if [[ ! -f /dev/shm/user_password ]] ;then
    while
      local fullname="Richard Gomes"
      read -e -i "${fullname}" -p "Enter full name for first user: " fullname
      [[ -z "${fullname}" ]]
    do true ;done

    local username=$(echo "${fullname}" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]' | sed -E 's/[ \t]+//g')
    while
      read -e -i "${username}" -p "Enter username for ${fullname}: " username
      [[ -z "${username}" ]]
    do true ;done

    while
      read -e -s -p "Enter a password for ${username}: " password
      read -e -s -p "Confirm password for ${username}: " confirm
      [[ -z "${password}" || ( "${password}" != "${confirm}" ) ]]
    do true ;done

    echo -n "${fullname}" > /dev/shm/user_fullname
    echo -n "${username}" > /dev/shm/user_username
    echo -n "${password}" > /dev/shm/user_password
  fi
}


function make_partitions() {
  echo "[ make_partitions ]"
  local device=$(cat /dev/shm/device)
  ##FIXME: allow configuration of swap space. Hardcoded to 16GiB at this point.
  sgdisk -Z               ${device}
  sgdisk -o               ${device}
  sgdisk -n 1:1MiB:513MiB ${device}
  sgdisk -n 2:0:+16GiB    ${device}
  sgdisk -n 3:0:+2GiB     ${device}
  sgdisk -n 4:0:-64KiB    ${device}
  sgdisk -c 1:efi         ${device}
  sgdisk -c 2:swap        ${device}
  sgdisk -c 3:boot        ${device}
  sgdisk -c 4:btrfs       ${device}
  sgdisk -t 1:ef00        ${device}
  sgdisk -t 2:8200        ${device}
  sgdisk -t 3:8300        ${device}
  sgdisk -t 4:8300        ${device}
  sgdisk -p               ${device}
}

function make_filesystems() {
  echo "[ make_filesystems ]"
  local device=$(cat /dev/shm/device)
  local partition=${device}p
  local passphrase=$(cat /dev/shm/luks_passphrase)
  # efi
  dd if=/dev/urandom of=${partition}1 count=10 bs=1M
  mkfs.vfat ${partition}1
  # boot
  dd if=/dev/urandom of=${partition}3 count=10 bs=1M
  mkfs.ext4 ${partition}3
  # swap
  dd if=/dev/urandom of=${partition}2 count=10 bs=1M
  echo -n "${passphrase}" | cryptsetup luksFormat -d - --type=luks2 ${partition}2
  echo -n "${passphrase}" | cryptsetup luksOpen   -d -              ${partition}2 cryptswap
  mkswap /dev/mapper/cryptswap
  # root (btrfs)
  dd if=/dev/urandom of=${partition}4 count=10 bs=1M
  echo -n "${passphrase}" | cryptsetup luksFormat -d - --type=luks2 ${partition}4
  echo -n "${passphrase}" | cryptsetup luksOpen   -d -              ${partition}4 cryptroot
  mkfs.btrfs /dev/mapper/cryptroot

  # debugging
  lsblk
}

function make_btrfs_volumes() {
  echo "[ make_btrfs_volumes ]"
  if (mount | grep /mnt) ;then umount /mnt ;fi
  mount /dev/mapper/cryptroot /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@snapshots
  # debugging
  lsblk
}

function mount_volumes() {
  echo "[ mount_volumes ]"
  local device=$(cat /dev/shm/device)
  local partition=${device}p
  ##XXX local options=ssd,noatime,compress=lzo,space_cache=v2,commit=120
  local options=noatime,compress=lzo,space_cache=v2
  # create directories for later mounting the volumes
  if (mount | grep /mnt) ;then umount /mnt ;fi
  mount -t btrfs -o ${options},subvol=@          /dev/mapper/cryptroot /mnt
  mkdir -p /mnt/home /mnt/.snapshots /mnt/boot
  mount -t btrfs -o ${options},subvol=@home      /dev/mapper/cryptroot /mnt/home
  mount -t btrfs -o ${options},subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
  # boot
  mount ${partition}3 /mnt/boot
  # efi
  mkdir -p /mnt/boot/efi
  mount ${partition}1 /mnt/boot/efi
  # swap
  swapon /dev/mapper/cryptswap
  # debugging
  lsblk
}

function install_debian() {
  echo "[ install_debian ]"
  local release="$(cat /dev/shm/release)"
  local mirror="$(cat /dev/shm/mirror)"
  apt update
  apt install -y debootstrap
  debootstrap --download-only ${release} /mnt ##VIXME: ${mirror}
  debootstrap ${release} /mnt ##FIXME: ${mirror}
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