#!/bin/bash -eux

function chroot_install_desktops() {
  echo "[ install_desktops ]"
  ##FIXME: allow selection of desired desktop(s)
  local desktop=kde-plasma-desktop
  apt update
  apt install -y ${desktop}
}

chroot_install_desktops
