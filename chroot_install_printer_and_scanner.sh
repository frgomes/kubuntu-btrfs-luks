#!/bin/bash -eu

function chroot_install_printer_and_scanner() {
  echo "[ install_printer_and_scanner ]"
  apt update
  ##FIXME: handle retries
  apt install -y cups printer-driver-cups-pdf system-config-printer skanlite xsane
  apt install -y cups printer-driver-cups-pdf system-config-printer skanlite xsane
  apt install -y cups printer-driver-cups-pdf system-config-printer skanlite xsane
}

chroot_install_printer_and_scanner
