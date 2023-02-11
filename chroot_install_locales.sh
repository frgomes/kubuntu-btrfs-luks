#!/bin/bash -eux

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
  apt install -y locales
  locale-gen "${language}.UTF-8"
  update-locale "LANG=${language}.UTF-8"
  locale-gen --purge "${language}.UTF-8"
}

chroot_install_locales
