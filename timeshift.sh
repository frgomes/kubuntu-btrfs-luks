#!/bin/bash

apt install -y btrfs-progs git make
apt install timeshift
timeshift-gtk
ls /run/timeshift/backup

# Now let’s install timeshift-autosnap-apt and grub-btrfs from GitHub
git clone https://github.com/wmutschl/timeshift-autosnap-apt.git /home/$USER/timeshift-autosnap-apt
cd /home/$USER/timeshift-autosnap-apt
make install

git clone https://github.com/Antynea/grub-btrfs.git /home/$USER/grub-btrfs
cd /home/$USER/grub-btrfs
make install
