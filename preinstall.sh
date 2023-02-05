#!/bin/bash -eux

function make_partitions() {
  local device=/dev/nvme0n1
  ##FIXME: allow configuration of swap space. Hardcoded to 16GiB at this point.
  parted ${device} <<EOD
mklabel gpt
mkpart primary 1MiB 513MiB
mkpart primary 513MiB 16897MiB
mkpart primary 16897MiB MiB 18495MiB
mkpart primary 18495MiB 100%
print
quit
EOD
}

function format_efi() {
  local device=/dev/nvme0n1
  # efi
  mkfs.vfat ${device}p1
}

function make_luks() {
  local device=/dev/nvme0n1
  echo -n "Enter passphrase for encrypted volume: "
  read -s passphrase
  # swap
  echo -n "${passphrase}" | cryptsetup luksFormat --type=luks2 ${device}p2 -
  echo -n "${passphrase}" | cryptsetup luksOpen ${device}p2 cryptswap -
  # root (btrfs)
  echo -n "${passphrase}" | cryptsetup luksFormat --type=luks2 ${device}p4 -
  echo -n "${passphrase}" | cryptsetup luksOpen ${device}p4 cryptroot -
}

function make_filesystems() {
  lsblk
  # swap
  mkswap /dev/mapper/cryptswap
  # root (btrfs)
  mkfs.btrfs /dev/mapper/cryptroot
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
  local options=,ssd,noatime,compress=zstd,space_cache=v2,commit=120
  # root (btrfs)
  mount -t btrfs -o ${options},subvol=@          /dev/mapper/cryptoroot /mnt
  mkdir -p /mnt/home /mnt/.snapshots
  mount -t btrfs -o ${options},subvol=@home      /dev/mapper/cryptoroot /mnt/home
  mount -t btrfs -o ${options},subvol=@snapshots /dev/mapper/cryptoroot /mnt/.snapshots
  # efi
  mkdir -p /mnt/boot/efi
  mount /mnt/${device}p1 /mnt/boot/efi
  # swap
  swapon /dev/mapper/cryptswap
}

function install_debian() {
  local character=bullseye
  apt update
  apt install -y debootstrap
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

function create_chroot() {
  for dir in sys dev proc ;do mount --rbind /${dir} /mnt/${dir} && mount --make-rslave /mnt/${dir} ;done
  cp /etc/resolv.conf /mnt/etc
  chroot /mnt /bin/bash
}

function install_locales() {
  apt update
  apt install -y locales
  apt-reconfigure locales
}

function install_btrfs_progs() {
  apt install -y btrfs-progs crypsetup
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
  make_partitions
  format_efi
  make_luks
  format_filesystems
  make_volumes
  mount_volumes
  install_debian
  update_sources
  create_chroot
  install_locales
  install_btrfs_progs
  install_kernel
  setup_root
  setup_user
  create_fstab
}
