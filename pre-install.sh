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
  # copy scripts
  local dir=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
  mkdir -p /mnt/tmp

  cp -rp ${dir} /mnt/tmp
  mv /mnt/tmp/kubuntu-btrfs-luks /mnt/tmp/chroot
  echo "[ /mnt/tmp/chroot ]"
  ls /mnt/tmp/chroot
  ### perform installation
  ##chroot /mnt /tmp/chroot/post-install.sh
  ##echo -n "PRESS ENTER"; read -s dummy
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




# function chroot_setup_password_root() {
#   echo "[ setup_passwd_root ]"
#   local password=password
#   local confirm=
#   while [ -z "${password}" -o \( "${password}" != "${confirm}" \) ] ;do
#     echo -n "Enter password for root: "
#     read -s password
#     echo ""
#     echo -n "Confirm password for root: "
#     read -s confirm
#     echo ""
#   done
#   echo -e "${password}\n${password}" | passwd --quiet root
#   ssh-keygen -b 4096 -t ed25519 -a 5 -f ~root/.ssh/id_ed25519 -N"${password}"
# }
#
# function chroot_setup_password_user() {
#   echo "[ setup_passwd_user ]"
#   local fullname=""
#   while [ -z "${fullname}" ] ;do
#     echo -n "Enter full name for first user: "
#     read fullname
#   done
#
#   local username=$(echo "${fullname}" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]' | sed -E 's/[ \t]+//g')
#   while
#     echo -n "Enter username for user ${fullname}: "
#     read -i "${username}" username
#     [[ -z "${username}" ]]
#   do true ;done
#
#   local password=password
#   local confirm=
#   while [ -z "${password}" -o \( "${password}" != "${confirm}" \) ] ;do
#     echo -n "Enter password for ${username}: "
#     read -s password
#     echo ""
#     echo -n "Confirm password for ${username}: "
#     read -s confirm
#     echo ""
#   done
#
#   useradd -m "${username}"
#   echo -e "${password}\n${password}" | passwd --quiet ${username}
#   ssh-keygen -b 4096 -t ed25519 -a 5 -f ~${username}/.ssh/id_ed25519 -N"${password}"
# }
#
# function chroot_install_locales() {
#   echo "[ install_locales ]"
#   local layout=gb
#   local lang=en_GB
#   # define default keyboard configuration
#   cat <<EOD > /etc/default/keyboard
# # KEYBOARD CONFIGURATION FILE
# # Consult the keyboard(5) and xkeyboard-config(7) manual page.
#
# XKBMODEL="pc105"
# XKBLAYOUT="${layout}"
# XKBVARIANT=""
# XKBOPTIONS="grp:alt_shift_toggle"
# BACKSPACE="guess"
# EOD
#
#   # define default locale configuration
#   apt update
#   apt install -y locales
#   update-locale "LANG=${lang}.UTF-8"
#   locale-gen --purge "${lang}.UTF-8"
#   dpkg-reconfigure --frontend noninteractive locales
# }
#
# function chroot_install_btrfs_progs() {
#   echo "[ install_btrfs_progs ]"
#   apt update
#   ##FIXME: handle retries
#   apt install -y btrfs-progs cryptsetup snapper
#   apt install -y btrfs-progs cryptsetup snapper
#   apt install -y btrfs-progs cryptsetup snapper
# }
#
# function chroot_install_kernel() {
#   echo "[ install_kernel ]"
#   ##FIXME: should detect hardware architecture
#   local hwarch=amd64
#   local firmware=$(apt search firmware | grep -E "^firmware-" | cut -d/ -f1 | fgrep -v microbit)
#   apt install -y linux-image-${hwarch} intel-microcode ${hwarch}-microcode
# }
#
# function chroot_create_fstab() {
#   echo "[ create_fstab ]"
#   local partition=/dev/nvme0n1p
#   local uuid_efi=$(blkid | fgrep ${partition}1 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
#   local uuid_swap=$(blkid | fgrep ${partition}2 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
#   local uuid_boot=$(blkid | fgrep ${partition}3 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
#   local uuid_root=$(blkid | fgrep ${partition}4 | cut -d' ' -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]')
#   cat /proc/mounts | grep -E "^/dev/mapper/|^tmpfs|^${partition}" | \
#     sed -E "s|^/dev/mapper/cryptroot|${uuid_root}|" | \
#     sed -E "s|^tmpfs|${uuid_root}|" | \
#     sed -E "s|/ btrfs|/           btrfs|" | \
#     sed -E "s|/home btrfs|/home       btrfs|" | \
#     sed -E "s|/@ 0 0|/           0 0|" | \
#     sed -E "s|/@home 0 0|/home       0 0|" | \
#     sed -E "s|${partition}1|${uuid_efi}|" > /etc/fstab
#   # debugging
#   cat /etc/fstab
# }
#
# function chroot_install_grub() {
#   echo "[ install_grub ]"
#   ##FIXME: should detect hardware architecture
#   local hwarch=amd64
#   apt install -y grub-efi-${hwarch}
# }
#
# function chroot_grub_enable_cryptodisk() {
#   echo "[ grub_enable_cryptodisk ]"
#   fgrep 'GRUB_ENABLE_CRYPTODISK=yes' /etc/default/grub || sed '/GRUB_CMDLINE_LINUX_DEFAULT/i GRUB_ENABLE_CRYPTODISK=yes' -i /etc/default/grub
#   sed 's/GRUB_ENABLE_CRYPTODISK=no/GRUB_ENABLE_CRYPTODISK=yes/' -i /etc/default/grub
#   local luks_config=$(blkid | fgrep 'TYPE="crypto_LUKS"' | cut -d' ' -f2 | cut -d= -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]' | sed -E 's/^/,rd.luks.uuid=/' | tr -d '\n')
#   echo ${luks_config}
#   sed "s/quiet/quiet${luks_config}/" -i /etc/default/grub
#   # debugging
#   cat /etc/default/grub
# }
#
# function chroot_create_volume_unlock_keys() {
#   echo "[ create_volume_unlock_keys ]"
#   local partition=/dev/nvme0n1p
#   local passphrase="$(cat /dev/shm/luks_passphrase)"
#   dd bs=1 count=512 if=/dev/urandom of=/boot/volume-swap.key
#   dd bs=1 count=512 if=/dev/urandom of=/boot/volume-root.key
#   echo "${passphrase}" | cryptsetup luksAddKey ${partition}2 /boot/volume-swap.key -
#   echo "${passphrase}" | cryptsetup luksAddKey ${partition}4 /boot/volume-root.key -
#   chmod 000 /boot/volume-swap.key
#   chmod 000 /boot/volume-root.key
#   chmod -R g-rwx,o-rwx /boot
# }
#
# function chroot_configure_crypttab() {
#   echo "[ configure_crypttab ]"
#   local partition=/dev/nvme0n1p
#   fgrep "${partition}" /etc/crypttab > /dev/null || cat <<EOD >> /etc/crypttab
# cryptswap ${partition}2 /boot/volume-swap.key luks,discard,key-slot=1
# cryptroot ${partition}4 /boot/volume-root.key luks,discard,key-slot=2
# EOD
#   # debugging
#   cat /etc/crypttab
# }
#
# function chroot_configure_initramfs() {
#   echo "[ configure_initramfs ]"
#   fgrep '#KEYFILE_PATTERN=' /etc/cryptsetup-initramfs/conf-hook > /dev/null || sed 's|#KEYFILE_PATTERN=|KEYFILE_PATTERN="/boot/*.key"|' -i /etc/cryptsetup-initramfs/conf-hook
#   cat /etc/cryptsetup-initramfs/conf-hook
# }
#
# function chroot_configure_initramfs_tools() {
#   echo "[ configure_initramfs_tools ]"
#   cat <<EOD
# UMASK=0077
# COMPRESS=gzip
# EOD
#   cat /etc/initramfs-tools/initramfs.conf
#   update-initramfs -u
#   # debugging
#   stat -Lc "%A %n" /initrd.img
#   lsinitramfs /initrd.img | grep -E "^crypt"
# }
#
# function chroot_configure_networking () {
#   echo "[ configure_networking  ]"
#   ##FIXME: hostname
#   local hostname=lua
#   local domain=mathminds.io
#   local timezone=BST
#   # hostname and domainname
#   ##FIXME: review line 127.0.1.1 on /etc/hosts
#   echo "${hostname}.${domainname}" > /etc/hostname
#   sed "s/localhost/${hostname}/g" -i /etc/hosts
#   # timezone
#   timedatectl set-timezone ${timezone}
#   # configure network-manager
#   apt install -y network-manager
#   systemctl enable NetworkManager dbus
#   update-grub
# }
#
# function chroot_install_desktops() {
#   echo "[ install_desktops ]"
#   ##FIXME: desktop
#   local desktop=kde-plasma-desktop
#   apt update
#   ##FIXME: handle retries
#   apt install -y ${desktop}
#   apt install -y ${desktop}
#   apt install -y ${desktop}
# }
#
# function chroot_install_mozilla_suite() {
#   echo "[ install_mozilla_suite ]"
#   apt update
#   ##FIXME: handle retries
#   apt install -y firefox-esr thunderbird
#   apt install -y firefox-esr thunderbird
#   apt install -y firefox-esr thunderbird
# }
#
# function chroot_install_office_suite() {
#   echo "[ install_office_suite ]"
#   apt update
#   ##FIXME: handle retries
#   apt install -y libreoffice gimp okular
#   apt install -y libreoffice gimp okular
#   apt install -y libreoffice gimp okular
# }
#
# function chroot_install_printer_and_scanner() {
#   echo "[ install_printer_and_scanner ]"
#   apt update
#   ##FIXME: handle retries
#   apt install -y cups printer-driver-cups-pdf system-config-printer skanlite xsane
#   apt install -y cups printer-driver-cups-pdf system-config-printer skanlite xsane
#   apt install -y cups printer-driver-cups-pdf system-config-printer skanlite xsane
# }
#
# function chroot_install_timeshift() {
#   echo "[ install_timeshift ]"
#   apt update
#   ##FIXME: handle retries
#   apt install -y timeshift snapper-gui
#   apt install -y timeshift snapper-gui
#   apt install -y timeshift snapper-gui
# }
#
# function chroot_install_syncthing() {
#   echo "[ install_syncthing ]"
#   apt update
#   ##FIXME: handle retries
#   apt install -y syncthing syncthing-discosrv syncthing-relaysrv syncthing-gtk
#   apt install -y syncthing syncthing-discosrv syncthing-relaysrv syncthing-gtk
#   apt install -y syncthing syncthing-discosrv syncthing-relaysrv syncthing-gtk
# }
#
# function chroot_install_utilities() {
#   echo "[ install_utilities ]"
#   apt update
#   # download managers
#   apt install -y wget curl
#   # text editors
#   apt install -y zile emacs vim
#   # source code management
#   apt install -y git gitk mercurial tortoisehg
#   # password mamagers
#   apt install -y keepassxc
#   # package managers
#   apt install -y flatpak
# }
#
# function chroot_enable_services() {
#   echo "[ enable_services ]"
#   # openssh-server
#   apt update
#   ##FIXME: handle retries
#   apt install -y openssh-server fail2ban
#   apt install -y openssh-server fail2ban
#   apt install -y openssh-server fail2ban
#   systemctl enable sshd
# }
#
# function chroot_finish_installation() {
#   echo "[ finish_installation ]"
#   snapper create --type single --description "Installation completed successfully" --userdata "important=yes"
#   sync; sync; sync
# }


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


  setup_chroot
  echo -n "PRESS ENTER"; read -s dummy

 #chroot /mnt ./chroot_setup_password_root.sh
  chroot /mnt /tmp/chroot/chroot_setup_password_root.sh
  echo -n "PRESS ENTER"; read -s dummy



  # chroot /mnt ./chroot_setup_password_user.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_install_locales.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_install_btrfs_progs.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_install_kernel.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_create_fstab.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_install_grub.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_grub_enable_cryptodisk.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_configure_crypttab.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_configure_initramfs.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_configure_initramfs_tools.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_configure_networking.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_install_desktops.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_install_mozilla_suite.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_install_office_suite.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_install_printer_and_scanner.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_install_utilities.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_enable_services.sh
  # echo -n "PRESS ENTER"; read -s dummy
  # chroot /mnt ./chroot_finish_installation.sh
  # echo -n "PRESS ENTER"; read -s dummy

  # umount_and_reboot
}
