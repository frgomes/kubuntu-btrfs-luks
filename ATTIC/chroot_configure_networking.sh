#!/bin/bash -eux

function chroot_configure_networking () {
  echo "[ configure_networking  ]"
  local hostname=$(cat /dev/shm/hostname)
  local domain=$(cat /dev/shm/domain)
  # hostname and domainname
  ##FIXME: review line 127.0.1.1 on /etc/hosts
  echo "${hostname}.${domain}" > /etc/hostname
  sed "s/localhost/${hostname}/g" -i /etc/hosts
  cat /etc/hosts
}

chroot_configure_networking