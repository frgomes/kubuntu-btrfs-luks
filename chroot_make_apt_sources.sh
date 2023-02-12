#!/bin/bash -eux

function chroot_make_apt_sources() {
  echo "[ update_sources ]"
  local release="$(cat /dev/shm/release)"
  local mirror="$(cat /dev/shm/mirror)"
  local hwarch="$(cat /dev/shm/hwarch)"
  cat <<EOD > /etc/apt/sources.list
deb     http://${mirror}/debian ${release} main contrib non-free
deb-src http://${mirror}/debian ${release} main contrib non-free
deb     http://${mirror}/debian-security/ ${release}-security main contrib non-free
deb-src http://${mirror}/debian-security/ ${release}-security main contrib non-free
deb     http://${mirror}/debian ${release}-updates main contrib non-free
deb-src http://${mirror}/debian ${release}-updates main contrib non-free

### backports
# deb     http://${mirror}/debian ${release}-backports main contrib non-free
# deb-src http://${mirror}/debian ${release}-backports main contrib non-free
EOD

  # debugging
  cat /etc/apt/sources.list
}

chroot_make_apt_sources
