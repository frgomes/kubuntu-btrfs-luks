#!/bin/bash -eux

function chroot_install_desktops() {
  echo "[ install_desktops ]"
  ##FIXME: desktop
  local desktop=kde-plasma-desktop
  apt update
  ##FIXME: handle retries
  apt install -y ${desktop}
  apt install -y ${desktop}
  apt install -y ${desktop}
}

chroot_install_desktops
