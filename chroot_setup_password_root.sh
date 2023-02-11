#!/bin/bash -eux

function chroot_setup_password_root() {
  echo "[ setup_passwd_root ]"
  local password=password
  local confirm=
  while [ -z "${password}" -o \( "${password}" != "${confirm}" \) ] ;do
    echo -n "Enter password for root: "
    read -s password
    echo ""
    echo -n "Confirm password for root: "
    read -s confirm
    echo ""
  done
  echo -e "${password}
${password}" | passwd --quiet root
  ##FIXME: ssh-keygen -b 4096 -t ed25519 -a 5 -f ~root/.ssh/id_ed25519 -N"${password}"
}

chroot_setup_password_root
