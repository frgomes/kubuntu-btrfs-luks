#!/bin/bash -eux

function chroot_enable_services() {
  echo "[ enable_services ]"
  # openssh-server
  apt update
  ##FIXME: handle retries
  apt install -y openssh-server fail2ban
  apt install -y openssh-server fail2ban
  apt install -y openssh-server fail2ban
  systemctl enable sshd
}

chroot_enable_services
