#!/bin/bash -eux

function chroot_install_locales() {
  echo "[ install_locales ]"
  local keyboard="$(cat /dev/shm/keyboard)"
  local language="$(cat /dev/shm/language)"
  local timezone="$(cat /dev/shm/timezone)"
  apt update
  apt install -y locales
  locale-gen "${language}.UTF-8"
  localectl set-keymap --no-convert "${keyboard}"
  localectl set-locale LC_ALL="${language}.UTF-8"
  timedatectl set-timezone ${timezone}
}

chroot_install_locales
