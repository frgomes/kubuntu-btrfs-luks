This is a set of shell scripts aiming to automate installation of Kubuntu 22.10 with BTRFS and LUKS disk encryption.

> WARNING: This is WORK IN PROGRESS and may not work as expected

See blog post [here](https://reckoning.dev/blog/ubuntu-btrfs-guide/)

## Requirements

* A bootable USB stick containing Kubuntu 22.10 image

> Debian and other variants of Debian may also work, but where not tested.

## For the impatient

Open a terminal window and become root:

    sudo -i

Now run commands below: which download shell scripts and perform the pre-installation process.

    git clone http://github.com/frgomes/kubuntu-btrfs-luks
    source ./kubuntu-btrfs-luks/preinstall.sh
    ubiquity --no-bootloader

> You need to follow the instructions in the [documentation](https://reckoning.dev/blog/ubuntu-btrfs-guide/).

Now run the post-installation script:	

    source ./kubuntu-btrfs-luks/postinstall.sh

Reboot.

After reboot, open a terminal window and become root:

    sudo -i

Now install Timeshift:

    source ./kubuntu-btrfs-luks/timeshift.sh
