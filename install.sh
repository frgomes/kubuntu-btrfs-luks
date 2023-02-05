#!/bin/bash -eux

function setup_passwd_root() {
  local password=password
  local confirm=
  while [ -z "${password}" -o \( "${password}" != "${confirm}" \) ] ;do
    echo -n "Enter password for root: "
    read -s password
    echo ""
    echo -n "Confirm password for root: "
    read -s confirm
    echo ""
  done
  echo -e "${password}\n${password}" | passwd --quiet root
}

function setup_passwd_user() {
  local fullname=""
  while [ -z "${fullname}" ] ;do
    echo -n "Enter full name for first user: "
    read fullname
  done

  local username=$(echo "${fullname}" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]' | sed -E 's/[ \t]+//g')
  while
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

  useradd -m "${username}"
  echo -e "${password}\n${password}" | passwd --quiet ${username}
}

function install_locales() {
  local layout=gb
  local lang=en_GB
  # define default keyboard configuration
  cat <<EOD > /etc/default/keyboard
# KEYBOARD CONFIGURATION FILE
# Consult the keyboard(5) and xkeyboard-config(7) manual page.

XKBMODEL="pc105"
XKBLAYOUT="${layout}"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOD

  # define default locale configuration
  apt update
  apt install -y locales
  update-locale "LANG=${lang}.UTF-8"
  locale-gen --purge "${lang}.UTF-8"
  dpkg-reconfigure --frontend noninteractive locales
}

function install_btrfs_progs() {
  apt install -y btrfs-progs cryptsetup
}

function install_kernel() {
  ##FIXME: should detect hardware architecture
  local hwarch=amd64
  local firmware=$(apt search firmware | grep -E "^firmware-" | cut -d/ -f1 | fgrep -v microbit)
  apt install -y linux-image-${hwarch} intel-microcode ${hwarch}-microcode
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
    sed -E "s|/ btrfs|/           btrfs|" | \
    sed -E "s|/home btrfs|/home       btrfs|" | \
    sed -E "s|/@ 0 0|/           0 0|" | \
    sed -E "s|/@home 0 0|/home       0 0|" | \
    sed -E "s|${device}p1|${uuid_efi}|" > /etc/fstab
  # debugging
  cat /etc/fstab
}

function install_grub() {
  ##FIXME: should detect hardware architecture
  local hwarch=amd64
  apt install -y grub-efi-${hwarch}
}

function grub_enable_cryptodisk() {
  fgrep 'GRUB_ENABLE_CRYPTODISK=yes' /etc/default/grub || sed '/GRUB_CMDLINE_LINUX_DEFAULT/i GRUB_ENABLE_CRYPTODISK=yes' -i /etc/default/grub
  sed 's/GRUB_ENABLE_CRYPTODISK=no/GRUB_ENABLE_CRYPTODISK=yes/' -i /etc/default/grub
  local luks_config=$(blkid | fgrep 'TYPE="crypto_LUKS"' | cut -d' ' -f2 | cut -d= -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]' | sed -E 's/^/,rd.luks.uuid=/' | tr -d '\n')
  echo ${luks_config}
  sed "s/quiet/quiet${luks_config}/" /etc/default/grub
  # debugging
  #cat /etc/default/grub
}


function automated_install() {
  setup_password_root
  setup_password_user
  install_locales
  install_btrfs_progs
  install_kernel
  create_fstab
  install_grub
  grub_enable_cryptodisk
}
