#!/bin/bash -eux

function make_partitions() {
  local drive=/dev/nvme0n1
  ##FIXME: allow configuration of swap space. Hardcoded to 16GiB at this point.
  parted -s ${drive} -- mklabel gpt
  parted -s ${drive} -- mkpart primary 1MiB 513MiB
  parted -s ${drive} -- mkpart primary 513MiB 16897MiB
  parted -s ${drive} -- mkpart primary 16897MiB 18495MiB
  parted -s ${drive} -- mkpart primary 18495MiB -64KiB
  parted -s ${drive} -- print
}

function make_luks() {
  local partition=/dev/nvme0n1p

  local passphrase=passphrase
  local confirm=wrong
  while [ "${passphrase}" != "${confirm}" ] ;do
    echo -n "Enter passphrase for encrypted volume: "
    read -s password
    echo ""
    echo -n "Confirm passphrase for encrypted volume: "
    read -s confirm
    echo ""
  done
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
  mount /dev/mapper/cryptroot /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@snapshots
  umount /mnt
  lsblk
}

function mount_volumes() {
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
  local character=bullseye
  apt update
  apt install -y debootstrap
  debootstrap --download-only ${character} /mnt
  debootstrap --download-only ${character} /mnt
  debootstrap --download-only ${character} /mnt
  debootstrap ${character} /mnt
}

function update_sources() {
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
}

function setup_chroot() {
  # bind volumes
  for dir in sys dev proc ;do mount --rbind /${dir} /mnt/${dir} && mount --make-rslave /mnt/${dir} ;done
  # setup networking
  cp /etc/resolv.conf /mnt/etc
  # copy scripts
  local dir=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
  mkdir -p /mnt/tmp
  cp -pv ${dir} /mnt/tmp
  # debugging
  ls -al /mnt/tmp/chroot
}

function automated_install() {
  make_partitions
  make_luks
  format_filesystems
  make_volumes
  mount_volumes
  install_debian
  update_sources
  setup_chroot
  # run next step in a jail
  local dir=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
  local base=$(dirname ${dir})
  chroot /mnt /tmp/${base}/install.sh
}
