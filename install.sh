#!/bin/bash -eux

function install_locales() {
  apt update
  apt install -y locales
  dpkg-reconfigure keyboard
  dpkg-reconfigure locales
}

function install_btrfs_progs() {
  apt install -y btrfs-progs cryptsetup
}

function install_kernel() {
  ##FIXME: should detect hardware architecture
  local firmware=$(apt search firmware | grep -E "^firmware-" | cut -d/ -f1 | fgrep -v microbit)
  apt install -y linux-image-amd64 intel-microcode amd64-microcode 
}

function setup_root() {
  local password=password
  local confirm=wrong
  while [ "${password}" != "${confirm}" ] ;do
    echo -n "Enter password for root: "
    read -s password
    echo -n "Confirm password for root: "
    read -s confirm
  done
  echo "${password}" | passwd root --stdin
}

function setup_user() {
  local fullname="Debian"
  echo -n "Enter full name of first user: "
  read fullname

  local username=$(echo "${fullname}" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
  echo -n "Enter username of first user: "
  read username

  local password=password
  local confirm=wrong
  while [ "${password}" != "${confirm}" ] ;do
    echo -n "Enter password for ${username}: "
    read -s password
    echo -n "Confirm password for ${username}: "
    read -s confirm
  done
  echo "${password}" | passwd ${username} --stdin
}

function create_fstab() {
  local device=/dev/nvme0n1
  local uuid_efi=$(blkid | fgrep ${device}p1 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_swap=$(blkid | fgrep ${device}p2 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_boot=$(blkid | fgrep ${device}p3 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_root=$(blkid | fgrep ${device}p4 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  cat /proc/mounts | grep -E "^/dev/mapper/|^tmpfs|^${device}" | \
    sed -E "s|^/dev/mapper/cryptroot|${uuid_root}|" | \
    sed -E "s|^tmpfs|${uuid_root}|" | \
    sed -E "s|${device}p1|${uuid_efi}|"
}


function automated_install() {
  install_locales
  install_btrfs_progs
  install_kernel
  setup_root
  setup_user
  create_fstab
}
