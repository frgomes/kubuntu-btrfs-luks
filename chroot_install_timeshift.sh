#!/bin/bash -eux

function chroot_install_timeshift() {
  echo "[ install_timeshift ]"
  apt update
  apt install -y timeshift snapper-gui
}

chroot_install_timeshift
