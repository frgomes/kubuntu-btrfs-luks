#!/bin/bash -eux

function chroot_grub_enable_cryptodisk() {
  echo "[ grub_enable_cryptodisk ]"
  fgrep 'GRUB_ENABLE_CRYPTODISK=yes' /etc/default/grub || sed '/GRUB_CMDLINE_LINUX_DEFAULT/i GRUB_ENABLE_CRYPTODISK=yes' -i /etc/default/grub
  sed 's/GRUB_ENABLE_CRYPTODISK=no/GRUB_ENABLE_CRYPTODISK=yes/' -i /etc/default/grub
  local luks_config=$(blkid | fgrep 'TYPE="crypto_LUKS"' | cut -d' ' -f2 | cut -d= -f2 | sed 's/"//g' | tr '[:lower:]' '[:upper:]' | sed -E 's/^/,rd.luks.uuid=/' | tr -d '
')
  local replace="quiet${luks_config},resume=/dev/mapper/cryptswap"
  echo REPLACE=${replace}
  sed -E "s/[\"]quiet[\"]/\"${replace}\"/" -i /etc/default/grub
  # debugging
  cat /etc/default/grub
}

chroot_grub_enable_cryptodisk
