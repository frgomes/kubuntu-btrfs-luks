#!/bin/bash -eux

function chroot_kernel_update() {
  echo "[ kernel_update ]"
  local hwarch="$(cat /dev/shm/hwarch)"
  local mirror="$(cat /dev/shm/mirror)"
  if ! grep unstable /etc/apt/sources.list > /dev/null ;then
     cat <<EOD >> /etc/apt/sources.list

### unstable
deb     http://${mirror}/debian unstable main contrib non-free
deb-src http://${mirror}/debian unstable main contrib non-free
EOD

  cat <<EOD > /etc/apt/preferences
Package: *
Pin: release a=bullseye
Pin-Priority: 500

Package: linux-image-${hwarch}
Pin:release a=unstable
Pin-Priority: 1000

Package: *
Pin: release a=unstable
Pin-Priority: 100
EOD
  fi

  apt update
  apt upgrade -y
  ##XXX local firmware=$(apt search firmware | grep -E "^firmware-" | cut -d/ -f1 | fgrep -v microbit)
  apt install -y firmware-linux
  update-grub
}

chroot_kernel_update
