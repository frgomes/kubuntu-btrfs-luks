#!/bin/bash -eux

function chroot_finish_installation() {
  echo "[ finish_installation ]"
  snapper create --type single --description "Installation completed successfully" --userdata "important=yes"
  sync; sync; sync
}

chroot_finish_installation
