#!/bin/bash -eux

function chroot_enable_services() {
  echo "[ enable_services ]"
  # openssh-server
  apt update
  ##FIXME: handle retries
  apt install -y openssh-server fail2ban
  apt install -y openssh-server fail2ban
  apt install -y openssh-server fail2ban

  local username=$(cat /dev/shm/user_username)
  local user_password="$(cat /dev/shm/user_password)"
  local root_password="$(cat /dev/shm/root_password)"

  ssh-keygen -b 4096 -t ed25519 -a 5 -f ~root/.ssh/id_ed25519 -N"${root_password}"
  ssh-keygen -b 4096 -t ed25519 -a 5 -f ~${username}/.ssh/id_ed25519 -N"${user_password}"

  ##FIXME: systemctl enable sshd
}

chroot_enable_services
