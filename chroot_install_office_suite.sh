function chroot_install_office_suite() {
  echo "[ install_office_suite ]"
  apt update
  ##FIXME: handle retries
  apt install -y libreoffice gimp okular
  apt install -y libreoffice gimp okular
  apt install -y libreoffice gimp okular
}
