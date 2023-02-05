#!/bin/bash -eux

function setup_passwd_root() {
  echo "[ setup_passwd_root ]"
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
  ssh-keygen -b 4096 -t ed25519 -a 5 -f ~root/.ssh/id_ed25519 -N"${password}"
}

function setup_passwd_user() {
  echo "[ setup_passwd_user ]"
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
  ssh-keygen -b 4096 -t ed25519 -a 5 -f ~${username}/.ssh/id_ed25519 -N"${password}"
}

function install_locales() {
  echo "[ install_locales ]"
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
  echo "[ install_btrfs_progs ]"
  apt update
  ##FIXME: handle retries
  apt install -y btrfs-progs cryptsetup snapper
  apt install -y btrfs-progs cryptsetup snapper
  apt install -y btrfs-progs cryptsetup snapper
}

function install_kernel() {
  echo "[ install_kernel ]"
  ##FIXME: should detect hardware architecture
  local hwarch=amd64
  local firmware=$(apt search firmware | grep -E "^firmware-" | cut -d/ -f1 | fgrep -v microbit)
  apt install -y linux-image-${hwarch} intel-microcode ${hwarch}-microcode
}

function create_fstab() {
  echo "[ create_fstab ]"
  local partition=/dev/nvme0n1p
  local uuid_efi=$(blkid | fgrep ${partition}1 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_swap=$(blkid | fgrep ${partition}2 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_boot=$(blkid | fgrep ${partition}3 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  local uuid_root=$(blkid | fgrep ${partition}4 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
  cat /proc/mounts | grep -E "^/dev/mapper/|^tmpfs|^${partition}" | \
    sed -E "s|^/dev/mapper/cryptroot|${uuid_root}|" | \
    sed -E "s|^tmpfs|${uuid_root}|" | \
    sed -E "s|/ btrfs|/           btrfs|" | \
    sed -E "s|/home btrfs|/home       btrfs|" | \
    sed -E "s|/@ 0 0|/           0 0|" | \
    sed -E "s|/@home 0 0|/home       0 0|" | \
    sed -E "s|${partition}1|${uuid_efi}|" > /etc/fstab
  # debugging
  cat /etc/fstab
}

function install_grub() {
  echo "[ install_grub ]"
  ##FIXME: should detect hardware architecture
  local hwarch=amd64
  apt install -y grub-efi-${hwarch}
}

function grub_enable_cryptodisk() {
  echo "[ grub_enable_cryptodisk ]"
  fgrep 'GRUB_ENABLE_CRYPTODISK=yes' /etc/default/grub || sed '/GRUB_CMDLINE_LINUX_DEFAULT/i GRUB_ENABLE_CRYPTODISK=yes' -i /etc/default/grub
  sed 's/GRUB_ENABLE_CRYPTODISK=no/GRUB_ENABLE_CRYPTODISK=yes/' -i /etc/default/grub
  local luks_config=$(blkid | fgrep 'TYPE="crypto_LUKS"' | cut -d' ' -f2 | cut -d= -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]' | sed -E 's/^/,rd.luks.uuid=/' | tr -d '\n')
  echo ${luks_config}
  sed "s/quiet/quiet${luks_config}/" -i /etc/default/grub
  # debugging
  cat /etc/default/grub
}

function create_volume_unlock_keys() {
  echo "[ create_volume_unlock_keys ]"
  local partition=/dev/nvme0n1p
  local passphrase="$(cat /dev/shm/luks_passphrase)"
  dd bs=1 count=512 if=/dev/urandom of=/boot/volume-swap.key
  dd bs=1 count=512 if=/dev/urandom of=/boot/volume-root.key
  echo "${passphrase}" | cryptsetup luksAddKey ${partition}2 /boot/volume-swap.key -
  echo "${passphrase}" | cryptsetup luksAddKey ${partition}4 /boot/volume-root.key -
  chmod 000 /boot/volume-swap.key
  chmod 000 /boot/volume-root.key
  chmod -R g-rwx,o-rwx /boot
}

function configure_crypttab() {
  echo "[ configure_crypttab ]"
  local partition=/dev/nvme0n1p
  fgrep "${partition}" /etc/crypttab > /dev/null || cat <<EOD >> /etc/crypttab
cryptswap ${partition}2 /boot/volume-swap.key luks,discard,key-slot=1
cryptroot ${partition}4 /boot/volume-root.key luks,discard,key-slot=2
EOD
  # debugging
  cat /etc/crypttab
}

function configure_initramfs() {
  echo "[ configure_initramfs ]"
  fgrep '#KEYFILE_PATTERN=' /etc/cryptsetup-initramfs/conf-hook > /dev/null || sed 's|#KEYFILE_PATTERN=|KEYFILE_PATTERN="/boot/*.key"|' -i /etc/cryptsetup-initramfs/conf-hook
  cat /etc/cryptsetup-initramfs/conf-hook
}

function configure_initramfs_tools() {
  echo "[ configure_initramfs_tools ]"
  cat <<EOD
UMASK=0077
COMPRESS=gzip
EOD
  cat /etc/initramfs-tools/initramfs.conf
  update-initramfs -u
  # debugging
  stat -Lc "%A %n" /initrd.img
  lsinitramfs /initrd.img | grep -E "^crypt"
}

function configure_networking () {
  echo "[ configure_networking  ]"
  ##FIXME: hostname
  local hostname=lua
  local domain=mathminds.io
  local timezone=BST
  # hostname and domainname
  ##FIXME: review line 127.0.1.1 on /etc/hosts
  echo "${hostname}.${domainname}" > /etc/hostname
  sed "s/localhost/${hostname}/g" -i /etc/hosts
  # timezone
  timedatectl set-timezone ${timezone}
  # configure network-manager
  apt install -y network-manager
  systemctl enable NetworkManager dbus
  update-grub
}

function install_desktops() {
  echo "[ install_desktops ]"
  ##FIXME: desktop
  local desktop=kde-plasma-desktop
  apt update
  ##FIXME: handle retries
  apt install -y ${desktop}
  apt install -y ${desktop}
  apt install -y ${desktop}
}

function install_mozilla_suite() {
  echo "[ install_mozilla_suite ]"
  apt update
  ##FIXME: handle retries
  apt install -y firefox-esr thunderbird
  apt install -y firefox-esr thunderbird
  apt install -y firefox-esr thunderbird
}

function install_office_suite() {
  echo "[ install_office_suite ]"
  apt update
  ##FIXME: handle retries
  apt install -y libreoffice gimp okular
  apt install -y libreoffice gimp okular
  apt install -y libreoffice gimp okular
}

function install_printer_and_scanner() {
  echo "[ install_printer_and_scanner ]"
  apt update
  ##FIXME: handle retries
  apt install -y cups printer-driver-cups-pdf system-config-printer skanlite xsane
  apt install -y cups printer-driver-cups-pdf system-config-printer skanlite xsane
  apt install -y cups printer-driver-cups-pdf system-config-printer skanlite xsane
}

function install_timeshift() {
  echo "[ install_timeshift ]"
  apt update
  ##FIXME: handle retries
  apt install -y timeshift snapper-gui
  apt install -y timeshift snapper-gui
  apt install -y timeshift snapper-gui
}

function install_syncthing() {
  echo "[ install_syncthing ]"
  apt update
  ##FIXME: handle retries
  apt install -y syncthing syncthing-discosrv syncthing-relaysrv syncthing-gtk
  apt install -y syncthing syncthing-discosrv syncthing-relaysrv syncthing-gtk
  apt install -y syncthing syncthing-discosrv syncthing-relaysrv syncthing-gtk
}

function install_utilities() {
  echo "[ install_utilities ]"
  apt update
  # download managers
  apt install -y wget curl
  # text editors
  apt install -y zile emacs vim
  # source code management
  apt install -y git gitk mercurial tortoisehg
  # password mamagers
  apt install -y keepassxc
  # package managers
  apt install -y flatpak
}

function enable_services() {
  echo "[ enable_services ]"
  # openssh-server
  apt update
  ##FIXME: handle retries
  apt install -y openssh-server fail2ban
  apt install -y openssh-server fail2ban
  apt install -y openssh-server fail2ban
  systemctl enable sshd
}

function finish_installation() {
  echo "[ finish_installation ]"
  snapper create --type single --description "Installation completed successfully" --userdata "important=yes"
  sync; sync; sync
}


function automated_chroot() {
  setup_password_root
  echo -n "PRESS ENTER"; read -s dummy
  setup_password_user
  echo -n "PRESS ENTER"; read -s dummy
  install_locales
  echo -n "PRESS ENTER"; read -s dummy
  install_btrfs_progs
  echo -n "PRESS ENTER"; read -s dummy
  install_kernel
  echo -n "PRESS ENTER"; read -s dummy
  create_fstab
  echo -n "PRESS ENTER"; read -s dummy
  install_grub
  echo -n "PRESS ENTER"; read -s dummy
  grub_enable_cryptodisk
  echo -n "PRESS ENTER"; read -s dummy
  configure_crypttab
  echo -n "PRESS ENTER"; read -s dummy
  configure_initramfs
  echo -n "PRESS ENTER"; read -s dummy
  configure_initramfs_tools
  echo -n "PRESS ENTER"; read -s dummy
  configure_networking
  echo -n "PRESS ENTER"; read -s dummy
  install_desktops
  echo -n "PRESS ENTER"; read -s dummy
  install_mozilla_suite
  echo -n "PRESS ENTER"; read -s dummy
  install_office_suite
  echo -n "PRESS ENTER"; read -s dummy
  install_printer_and_scanner
  echo -n "PRESS ENTER"; read -s dummy
  install_utilities
  echo -n "PRESS ENTER"; read -s dummy
  enable_services
  echo -n "PRESS ENTER"; read -s dummy
  finish_installation
  echo -n "PRESS ENTER"; read -s dummy
}


automated_chroot
