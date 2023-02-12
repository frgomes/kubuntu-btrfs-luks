#!/bin/bash -eux

source ./functions_bootstrap.sh
source ./functions_chroot.sh

mount_volumes
read -p "Press ENTER"

setup_chroot
read -p "Press ENTER"

deploy_chroot_scripts
read -p "Press ENTER"

chroot_kernel_update
read -p "Press ENTER"
