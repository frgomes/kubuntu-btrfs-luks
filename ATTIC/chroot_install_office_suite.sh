#!/bin/bash -eux

function chroot_install_office_suite() {
  echo "[ install_office_suite ]"
  apt update
  apt install -y libreoffice gimp okular
}

chroot_install_office_suite
