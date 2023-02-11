#!/bin/bash -eux

function chroot_install_locales() {
  echo "[ install_locales ]"
  local keyboard="$(cat /dev/shm/keyboard)"
  local language="$(cat /dev/shm/language)"
  local timezone="$(cat /dev/shm/timezone)"

  loadkeys "${keyboard}"
  sudo dpkg-reconfigure --frontend noninteractive console-setup

  # define default locale configuration
  apt update
  apt install -y locales

  ##XXX locale-gen "${lang}.UTF-8"
  ##XXX dpkg-reconfigure --frontend noninteractive locales
  ##XXX update-locale "LANG=${lang}.UTF-8"

  echo "locales locales/default_environment_locale select      ${language}.UTF-8"       | debconf-set-selections
  echo "locales locales/locales_to_be_generated    multiselect ${language}.UTF-8 UTF-8" | debconf-set-selections
  rm "/etc/locale.gen"
  dpkg-reconfigurel --frontend noninteractive locales

  timedatectl set-timezone ${timezone}
}

chroot_install_locales
