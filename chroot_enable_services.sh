#!/bin/bash -eu

function chroot_enable_services() {
  echo "[ enable_services ]"
  systemctl enable NetworkManager dbus
}

chroot_enable_services
