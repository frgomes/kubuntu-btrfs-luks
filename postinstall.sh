#!/bin/bash -eux

echo -n "Enter passphrase for encrypted volume: "
read -s passphrase
echo ""

# Create a chroot environment and enter your system
#mount -o subvol=@,ssd,noatime,space_cache,commit=120,compress=zstd /dev/mapper/cryptdata /mnt
mount -o subvol=@,ssd /dev/mapper/cryptdata /mnt
for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt$i; done
cp /etc/resolv.conf /mnt/etc/
chroot /mnt
mount -av

# Create crypttab
export UUID_p3=$(blkid -s UUID -o value /dev/nvme0n1p3) #this is an environmental variable
echo "cryptdata UUID=${UUID_p3} none luks" >> /etc/crypttab
cat /etc/crypttab

# Encrypted swap
export SWAPUUID=$(blkid -s UUID -o value /dev/nvme0n1p2)
echo "cryptswap UUID=${SWAPUUID} /dev/urandom swap,offset=1024,cipher=aes-xts-plain64,size=512" >> /etc/crypttab
cat /etc/crypttab
sed -i "s|UUID=${SWAPUUID}|/dev/mapper/cryptswap|" /etc/fstab
cat /etc/fstab

# Add a key-file to type luks passphrase only once (optional, but recommended)
mkdir /etc/luks
dd if=/dev/urandom of=/etc/luks/boot_os.keyfile bs=4096 count=1
chmod u=rx,go-rwx /etc/luks
chmod u=r,go-rwx /etc/luks/boot_os.keyfile
echo -n "${passphrase}" | cryptsetup luksAddKey /dev/nvme0n1p3 /etc/luks/boot_os.keyfile

# Enter any existing passphrase:
echo ENTER EXISTING PASSPHRASE
echo -n "${passphrase}" | cryptsetup luksDump /dev/nvme0n1p3 | grep "Key Slot"
echo "KEYFILE_PATTERN=/etc/luks/*.keyfile" >> /etc/cryptsetup-initramfs/conf-hook
echo "UMASK=0077" >> /etc/initramfs-tools/initramfs.conf
sed -i "s|none|/etc/luks/boot_os.keyfile|" /etc/crypttab # this replaces none with /etc/luks/boot_os.keyfile
cat /etc/crypttab

# Install the EFI bootloader
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
apt install -y --reinstall grub-efi-amd64-signed linux-generic linux-headers-generic linux-generic-hwe-22.04 linux-headers-generic-hwe-22.04
update-initramfs -c -k all
grub-install /dev/nvem0n1
update-grub
stat -L -c "%A  %n" /boot/initrd.img
lsinitramfs /boot/initrd.img | grep "^cryptroot/keyfiles/"

# Step 6: Reboot, some checks, and update system
exit
sync; sync; sync
reboot now
