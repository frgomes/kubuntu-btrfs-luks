function chroot_configure_networking () {
  echo "[ configure_networking  ]"
  ##FIXME: hostname
  local hostname=lua
  local domain=mathminds.io
  local timezone=BST
  # hostname and domainname
  ##FIXME: review line 127.0.1.1 on /etc/hosts
  echo "${hostname}.${domainname}" > /etc/hostname
  sed "s/localhost/${hostname}/g" -i /etc/hosts
  # timezone
  timedatectl set-timezone ${timezone}
  # configure network-manager
  apt install -y network-manager
  systemctl enable NetworkManager dbus
  update-grub
}
