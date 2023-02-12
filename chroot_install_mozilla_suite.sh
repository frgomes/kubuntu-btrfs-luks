#!/bin/bash -eux

function chroot_install_mozilla_suite() {
  echo "[ install_mozilla_suite ]"
  apt update
  apt install -y firefox-esr thunderbird
}

chroot_install_mozilla_suite
