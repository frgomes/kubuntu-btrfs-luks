#!/bin/bash -eu

function chroot_install_locales() {
  echo "[ install_locales ]"
  local keyboard="$(cat /dev/shm/keyboard)"
  local language="$(cat /dev/shm/language)"
  local timezone="$(cat /dev/shm/timezone)"

  apt update
  apt install -y locales

  cat <<EOD > /etc/default/keyboard
# KEYBOARD CONFIGURATION FILE
# Consult the keyboard(5) and xkeyboard-config(7) manual page.

XKBMODEL="pc105"
XKBLAYOUT="${keyboard}"
XKBVARIANT=""
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOD
  dpkg-reconfigure --frontend=noninteractive keyboard-configuration

  sed -E "s/# ${language}.UTF-8 UTF-8/${language}.UTF-8 UTF-8/" -i /etc/locale.gen
  echo LANG="${language}.UTF-8" > /etc/default/locale
  dpkg-reconfigure --frontend=noninteractive locales
  update-locale LANG="${language}.UTF-8"

  echo "${timezone}" > /etc/timezone
  dpkg-reconfigure --frontend=noninteractive tzdata
}

chroot_install_locales
