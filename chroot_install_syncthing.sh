#!/bin/bash -eu

function chroot_install_syncthing() {
  echo "[ install_syncthing ]"
  apt update
  ##FIXME: handle retries
  apt install -y syncthing syncthing-discosrv syncthing-relaysrv syncthing-gtk
  apt install -y syncthing syncthing-discosrv syncthing-relaysrv syncthing-gtk
  apt install -y syncthing syncthing-discosrv syncthing-relaysrv syncthing-gtk
}

chroot_install_syncthing
