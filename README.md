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

Usage:

vpn.sh [-c|--chroot DIR][--proxy proxy_string] -i|--install
vpn.sh [--vpn FQDN][-c|--chroot DIR] start|stop|status
vpn.sh [-c|--chroot DIR] uninstall
vpn.sh disconnect|split|selfupdate
vpn.sh -h|--help
vpn.sh -v|--version

-i|--install install mode - create chroot
-c|--chroot  change default chroot /opt/chroot directory
-h|--help    show this help
-v|--version script version
--vpn        select another VPN DNS full name
--proxy      proxy to use in apt inside chroot 'http://user:pass@IP'

start        start CShell daemon
stop         stop  CShell daemon
status       check if CShell daemon is running
disconnect   disconnect VPN/SNX session from the command line
split        split tunnel VPN - use only after session is up
uninstall    delete chroot and host file(s)
selfupdate   self update this script if new version available

For debugging/maintenance:

vpn.sh -d|--debug
vpn.sh shell

-d|--debug   bash debug mode on
shell        bash shell inside chroot

