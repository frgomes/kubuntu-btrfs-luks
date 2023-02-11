#!/bin/bash -eux

function chroot_setup_password_user() {
  echo "[ setup_passwd_user ]"
  local fullname=""
  while [ -z "${fullname}" ] ;do
    echo -n "Enter full name for first user: "
    read fullname
  done

  local username=$(echo "${fullname}" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]' | sed -E 's/[ \t]+//g')
  while
    echo -n "Enter username for user ${fullname}: "
    read -i "${username}" username
    [[ -z "${username}" ]]
  do true ;done

  local password=password
  local confirm=
  while [ -z "${password}" -o \( "${password}" != "${confirm}" \) ] ;do
    echo -n "Enter password for ${username}: "
    read -s password
    echo ""
    echo -n "Confirm password for ${username}: "
    read -s confirm
    echo ""
  done

  useradd -m "${username}"
  echo -e "${password}
${password}" | passwd --quiet ${username}
  ##FIXME: ssh-keygen -b 4096 -t ed25519 -a 5 -f ~${username}/.ssh/id_ed25519 -N"${password}"
}

chroot_setup_password_user
