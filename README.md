# chrootvpn
Checkpoint R80+ VPN client chroot wrapper

 VPN client chroot'ed setup/wrapper for Debian/Ubuntu
Checkpoint R80.10 and up

first time run it as sudo ./vpn.sh -i

It will get CShell and SNX installations scripts from the firewall, and install them.
CShell installation script patch included at the end of file.

non-chroot version not written intencionally.
SNX/CShell behave on odd ways ; the chroot is built to counter some of those behaviours

CShell CheckPoint Java agent needs Java *and* X11 desktop rights
binary SNX VPN client needs 32-bits environment

tested with chroot Debian Bullseye 11 (32 bits)
hosts: Debian 10, Debian 11, Ubuntu LTS 18.04, Ubuntu LTS 22.04
