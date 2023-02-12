#!/bin/bash -eu

function chroot_install_timeshift() {
  echo "[ install_timeshift ]"
  apt update
  ##FIXME: handle retries
  apt install -y timeshift snapper-gui
  apt install -y timeshift snapper-gui
  apt install -y timeshift snapper-gui
}

chroot_install_timeshift
