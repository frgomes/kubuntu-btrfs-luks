#!/bin/bash -eux

function chroot_install_locales() {
  echo "[ install_locales ]"
  local layout=gb
  local lang=en_US
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
  locale-gen "${lang}.UTF-8"
  dpkg-reconfigure --frontend noninteractive locales
  update-locale "LANG=${lang}.UTF-8"
}

chroot_install_locales
