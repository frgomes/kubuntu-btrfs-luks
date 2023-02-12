#!/bin/bash -eux

function chroot_make_apt_sources() {
  echo "[ update_sources ]"
  local release="$(cat /dev/shm/release)"
  local mirror="$(cat /dev/shm/mirror)"
  local hwarch="$(cat /dev/shm/hwarch)"
  cat <<EOD > /etc/apt/sources.list
deb     http://${mirror}/debian ${release} main contrib non-free
deb-src http://${mirror}/debian ${release} main contrib non-free
deb     http://${mirror}/debian-security/ ${release}-security main contrib non-free
deb-src http://${mirror}/debian-security/ ${release}-security main contrib non-free
deb     http://${mirror}/debian ${release}-updates main contrib non-free
deb-src http://${mirror}/debian ${release}-updates main contrib non-free

### backports
# deb     http://${mirror}/debian ${release}-backports main contrib non-free
# deb-src http://${mirror}/debian ${release}-backports main contrib non-free
EOD

  # debugging
  echo "================================================================================================"
  cat /etc/apt/sources.list
  echo "================================================================================================"
}

function chroot_setup_password_root() {
  echo "[ setup_password_root ]"
  local password="$(cat /dev/shm/root_password)"
  echo "root:${password}" | chpasswd
}

function chroot_setup_password_root() {
  echo "[ setup_password_root ]"
  local password="$(cat /dev/shm/root_password)"
  echo "root:${password}" | chpasswd
}

function chroot_setup_password_user() {
  echo "[ setup_password_user ]"
  local fullname=$(cat /dev/shm/user_fullname)
  local username=$(cat /dev/shm/user_username)
  local password="$(cat /dev/shm/user_password)"
  [[ -d /home/${username} ]] || useradd -m "${username}" -c "${fullname}"
  echo "${username}:${password}" | chpasswd
}

function chroot_install_locales() {
  echo "[ install_locales ]"
  local keyboard="$(cat /dev/shm/keyboard)"
  local language="$(cat /dev/shm/language)"
  local timezone="$(cat /dev/shm/timezone)"

  cat <<EOD > /etc/default/keyboard
# KEYBOARD CONFIGURATION FILE
# Consult the keyboard(5) and xkeyboard-config(7) manual page.

XKBMODEL="pc105"
XKBLAYOUT="${keyboard}"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOD

  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y keyboard-configuration locales

  sed -E "s/# ${language}.UTF-8 UTF-8/${language}.UTF-8 UTF-8/" -i /etc/locale.gen
  echo LANG="${language}.UTF-8" > /etc/default/locale
  dpkg-reconfigure --frontend=noninteractive locales
  update-locale LANG="${language}.UTF-8"

  echo "${timezone}" > /etc/timezone
  dpkg-reconfigure --frontend=noninteractive tzdata
}

function chroot_install_missing_packages() {
  echo "[ install_btrfs_progs ]"
  apt update
  DEBIAN_FRONTEND=noninteractive apt install -y btrfs-progs cryptsetup
}

function chroot_install_kernel() {
  echo "[ install_kernel ]"
  local hwarch=$(cat /dev/shm/hwarch)
  DEBIAN_FRONTEND=noninteractive apt install -y linux-image-${hwarch} intel-microcode ${hwarch}-microcode sudo network-manager
}

function chroot_create_fstab() {
  echo "[ create_fstab ]"
  local device="$(cat /dev/shm/device)"
  local partition="${device}"p
  local uuid_efi=$(blkid  | fgrep ${partition}1 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_swap=$(blkid | fgrep ${partition}2 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_boot=$(blkid | fgrep ${partition}3 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_root=$(blkid | fgrep ${partition}4 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  cat /proc/mounts | grep -v -E '^tmpfs' | grep -E "^/dev/mapper/|^${partition}" | \
    sed -E "s|^/dev/mapper/cryptroot|${uuid_root}|" | \
    sed -E "s|${partition}1|${uuid_efi}|" | \
    sed -E "s|^${partition}3|${uuid_boot}|" | \
    sed -E "s|/ btrfs|/           btrfs|" | \
    sed -E "s|/home btrfs|/home       btrfs|" | \
    sed -E "s|/boot ext4|/boot       ext4 |" | \
    sed -E "s|/@ 0 0|/           0 0|" | \
    sed -E "s|/@home 0 0|/home       0 0|" > /etc/fstab
  echo "tmpfs /tmp tmpfs rw,nosuid,nodev 0 0" >> /etc/fstab
  # debugging
  echo "================================================================================================"
  cat /etc/fstab
  echo "================================================================================================"
}

function chroot_install_grub() {
  echo "[ install_grub ]"
  local hwarch="$(cat /dev/shm/hwarch)"
  apt install -y grub-efi-${hwarch}
}

function chroot_grub_enable_cryptodisk() {
  echo "[ grub_enable_cryptodisk ]"
  fgrep 'GRUB_ENABLE_CRYPTODISK=yes' /etc/default/grub || sed '/GRUB_CMDLINE_LINUX_DEFAULT/i GRUB_ENABLE_CRYPTODISK=yes' -i /etc/default/grub
  sed 's/GRUB_ENABLE_CRYPTODISK=no/GRUB_ENABLE_CRYPTODISK=yes/' -i /etc/default/grub
  local luks_config=$(blkid | fgrep 'TYPE="crypto_LUKS"' | cut -d' ' -f2 | cut -d= -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]' | sed -E 's/^/,rd.luks.uuid=/' | tr -d \\n)
  local replace="quiet${luks_config},resume=/dev/mapper/cryptswap"
  sed -E "s:[\"]quiet[\"]:\"${replace}\":" -i /etc/default/grub
  # debugging
  echo "================================================================================================"
  cat /etc/default/grub
  echo "================================================================================================"
}

function chroot_configure_crypttab() {
  echo "[ create_volume_unlock_keys ]"
  local device=$(cat /dev/shm/device)
  local partition=${device}p
  local passphrase=$(cat /dev/shm/luks_passphrase)
  dd bs=1 count=512 if=/dev/urandom of=/boot/volume-swap.key
  dd bs=1 count=512 if=/dev/urandom of=/boot/volume-root.key
  echo -n "${passphrase}" | cryptsetup luksAddKey -d - ${partition}4 /boot/volume-root.key
  echo -n "${passphrase}" | cryptsetup luksAddKey -d - ${partition}2 /boot/volume-swap.key
  chmod 000 /boot/volume-root.key
  chmod 000 /boot/volume-swap.key
  chmod -R g-rwx,o-rwx /boot
  # create /etc/crypttab
  fgrep "${partition}" /etc/crypttab > /dev/null || cat <<EOD >> /etc/crypttab
cryptroot ${partition}4 /boot/volume-root.key luks,discard,key-slot=1
cryptswap ${partition}2 /boot/volume-swap.key luks,discard,key-slot=2
EOD
  # debugging
  cat /etc/crypttab
}

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

function chroot_configure_networking () {
  echo "[ configure_networking  ]"
  local hostname=$(cat /dev/shm/hostname)
  local domain=$(cat /dev/shm/domain)
  # hostname and domainname
  ##FIXME: review line 127.0.1.1 on /etc/hosts
  echo "${hostname}.${domain}" > /etc/hostname
  sed "s/localhost/${hostname}/g" -i /etc/hosts
  echo "================================================================================================"
  cat /etc/hosts
  echo "================================================================================================"
}

function chroot_install_opensshd() {
  echo "[ enable_services ]"
  apt update
  apt install -y openssh-server fail2ban

  local username=$(cat /dev/shm/user_username)
  local user_password="$(cat /dev/shm/user_password)"
  local root_password="$(cat /dev/shm/root_password)"

  [[ -d /root/.ssh ]] || (mkdir -p /root/.ssh; chmod 700 /root/.ssh )
  [[ -f ~root/.ssh/id_ed25519 ]] || ssh-keygen -b 4096 -t ed25519 -a 5 -f ~root/.ssh/id_ed25519 -N"${root_password}"

  [[ -d "~${username}/.ssh" ]] || (mkdir -p "~${username}/.ssh"; chmod 700 "~${username}/.ssh" )
  [[ -f "~${username}/.ssh/id_ed25519" ]] || ssh-keygen -b 4096 -t ed25519 -a 5 -f "~${username}/.ssh/id_ed25519" -N"${user_password}"
}

function chroot_uefi_run_grub() {
  echo "[ uefi_run_grub ]"
  local device=$(cat /dev/shm/device)
  grub-install ${device}
  update-grub
}

function chroot_enable_services() {
  echo "[ enable_services ]"
  systemctl enable NetworkManager dbus
}


chroot_make_apt_sources
read -p "Press ENTER"
chroot_setup_password_root
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
