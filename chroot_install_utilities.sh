#!/bin/bash -eux

function chroot_install_utilities() {
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

chroot_install_utilities
