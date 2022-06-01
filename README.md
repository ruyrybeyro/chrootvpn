# chrootvpn  

Checkpoint R80+ VPN client chroot wrapper

VPN client chroot'ed Debian setup/wrapper 

for Debian/Ubuntu/RH/CentOS/Fedora based hosts

Checkpoint R80.10 and up

https://github.com/ruyrybeyro/chrootvpn

Rui Ribeiro 2022

Tiago Teles - Contributions for Arch Linux 

Please fill VPN and VPNIP before using this script.
SPLIT might or not have to be filled, depending on your needs
and Checkpoint VPN routes.

if /opt/etc/vpn.conf is present the above script settings will be 
ignored. vpn.conf is created upon first instalation.

- first time, if filled VPN, VPNIP inside the script run it as 

	
	./vpn.sh -i

Otherwise, run it as:

        ./vnp.sh -i --vpn=FQDN_DNS_name_of_VPN
	

- accept localhost certificate in brower if not Firefox or if Firefox is a snap

	https://localhost:14186/id 

- visit VPN page for logging in 

It will get Mobile Access Portal Agent (CShell) and SSL Network Extender (SNX) installations scripts from the firewall, and install them.

non-chroot version not written intencionally.
SNX/CShell behave on odd ways ; the chroot is built to counter some of those behaviours

CShell CheckPoint Java agent needs Java *and* X11 desktop rights
binary SNX VPN client needs 32-bits environment.

Recommended having Firefox already installed, for deploying a firefox policy for the self-signed Mobile Access Portal Agent X.509 certificate.

Usage:

vpn.sh [-c DIR|--chroot=DIR][--proxy=proxy_string][--vpn=FQDN][--oldjava] -i|--install

vpn.sh [-o FILE|--output=FILE][-c|--chroot=DIR] start|stop|restart|status

vpn.sh [-c DIR|--chroot=DIR] uninstall

vpn.sh [-o FILE|--output=FILE] disconnect|split|selfupdate|fixdns

vpn.sh -h|--help

vpn.sh -v|--version

-i|--install install mode - create chroot

-c|--chroot  change default chroot /opt/chroot directory

-h|--help    show this help

-v|--version script version

--vpn        select VPN DNS full name install time

--proxy      proxy to use in apt inside chroot 'http://user:pass@IP'

--oldjava    JDK 8 for connecting to old Checkpoint VPN servers (circa 2019) *experimental*

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
vpn.sh [-c DIR|--chroot=DIR] shell|upgrade

vpn.sh shell


-d|--debug   bash debug mode on

shell        bash shell inside chroot

upgrade      OS upgrade inside chroot

KNOWN FEATURES

. The script/chroot is not designed to allow automatic remote deploying of new versions of both CShell (or SNX?)-aparently this functionality is not supported for Linux clients. If the status command of this script shows new versions, uninstall and install it again;

. The CShell daemon runs with a separate non-privileged user, and not using the logged in user;

. if using Firefox, is advised to have it installed *before* running this script;

. if Firefox is reinstalled, better uninstall and (re)install it, for the certificate policy file be deployed again.

COMPATIBILITY

Tested with chroot Debian Bullseye 11 (32 bits)

Tested with hosts:

Debian 10

Debian 11

Ubuntu LTS 18.04

Ubuntu LTS 22.04

Mint   20.2

antiX-21

Pop!_OS 22.04 LTS

Kubuntu 22.04 LTS

lubuntu 22.04 LTS

Kali 2022.2

Fedora 23

Fedora 36

CentOS 8

Rocky 8.6

Oracle 8.6

CentOS 9 stream

AlmaLinux 9.0

Arch Linux
