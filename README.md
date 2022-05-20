# chrootvpn  

Checkpoint R80+ VPN client chroot wrapper

VPN client chroot'ed Debian setup/wrapper 

for Debian/Ubuntu/RH/CentOS/Fedora hosts

Checkpoint R80.10 and up

Rui Ribeiro 2022

Please fill VPN and VPNIP before using this script.
SPLIT might or not have to be filled, depending on your needs
and Checkpoint VPN routes.

if /opt/etc/vpn.conf is present the above script settings will be 
ignored. vpn.conf is created upon first instalation.

- first time, if filled VPN, VPNIP inside the script run it as 

	
	sudo ./vpn.sh -i

Otherwise, run it as:

        sudo ./vnp.sh -i --vpn=FQDN_DNS_name_of_VPN
	

- accept localhost certificate in brower if not Firefox

	https://localhost:14186/id 

- visit VPN page for logging in 

It will get Mobile Access Portal Agent (CShell) and SSL Network Extender (SNX) installations scripts from the firewall, and install them.

CShell installation script patch included at the end of file.

non-chroot version not written intencionally.
SNX/CShell behave on odd ways ; the chroot is built to counter some of those behaviours

CShell CheckPoint Java agent needs Java *and* X11 desktop rights
binary SNX VPN client needs 32-bits environment

tested with chroot Debian Bullseye 11 (32 bits)
hosts: Debian 10, Debian 11, Ubuntu LTS 18.04, Ubuntu LTS 22.04

Usage:

vpn.sh [-c DIR|--chroot=DIR][--proxy=proxy_string][--vpn=FQDN] -i|--install

vpn.sh [-o FILE|--output=FILE][-c|--chroot=DIR] start|stop|restart|status

vpn.sh [-c DIR|--chroot=DIR] uninstall

vpn.sh [-o FILE|--output=FILE] disconnect|split|selfupdate|fixdns

vpn.sh -h|--help

vpn.sh -v|--version

-i|--install install mode - create chroot

-c|--chroot  change default chroot /opt/chroot directory

-h|--help    show this help

-v|--version script version

--vpn        select another VPN DNS full name

--proxy      proxy to use in apt inside chroot 'http://user:pass@IP'

-o|--output  redirect ALL output for FILE

-s|--silent  special case of output, no arguments


start        start CShell daemon

stop         stop  CShell daemon

restart      restart CShell daemon

status       check if CShell daemon is running

disconnect   disconnect VPN/SNX session from the command line

split        split tunnel VPN - use only after session is up

uninstall    delete chroot and host file(s)

selfupdate   self update this script if new version available

fixdns       try to fix resolv.conf


For debugging/maintenance:


vpn.sh -d|--debug
vpn.sh [-c DIR|--chroot DIR] shell|upgrade

vpn.sh shell


-d|--debug   bash debug mode on

shell        bash shell inside chroot

upgrade      OS upgrade inside chroot




Tested with hosts:

Debian 10

Debian 11

Ubuntu LTS 18.04

Ubuntu LTS 22.04

Mint   20.2

Fedora 8

CentOS 8

CentOS 9 stream

Rocky 8.6
