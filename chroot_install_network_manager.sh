#!/bin/bash -eux

function chroot_install_network_manager() {
  echo "[ install_network_manager ]"
  apt update
  apt install -y network-manager
}

chroot_install_network_manager
