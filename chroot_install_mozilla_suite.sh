#!/bin/bash -eu

function chroot_install_mozilla_suite() {
  echo "[ install_mozilla_suite ]"
  apt update
  ##FIXME: handle retries
  apt install -y firefox-esr thunderbird
  apt install -y firefox-esr thunderbird
  apt install -y firefox-esr thunderbird
}

chroot_install_mozilla_suite
