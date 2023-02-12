#!/bin/bash -eux

function chroot_install_syncthing() {
  echo "[ install_syncthing ]"
  apt update
  apt install -y syncthing syncthing-discosrv syncthing-relaysrv syncthing-gtk
}

chroot_install_syncthing
