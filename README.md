# chrootvpn  

Checkpoint R80+ VPN client chroot wrapper

VPN client chroot'ed Debian setup/wrapper 

for Debian/Ubuntu/RH/CentOS/Fedora/Arch/SUSE based hosts

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

--oldjava    JDK 8 for connecting to old Checkpoint VPN servers (circa 2019) *experimental* -- not sure it is needed

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
==============

. The CShell daemon writes over X11; if VPN is not working when called/installed from an ssh session, or afterr logging in, start/restart the script using a X11 graphical terminal;

. The script/chroot is not designed to allow automatic remote deploying of new versions of both CShell (or SNX?)-aparently this functionality is not supported for Linux clients. If the status command of this script shows new versions, uninstall and install it again;

. The CShell daemon runs with a separate non-privileged user, and not using the logged in user;

. if using Firefox, is advised to have it installed *before* running this script;

. if Firefox is reinstalled, better uninstall and (re)install it, for the certificate policy file be deployed again;

. if TZ is not set before the script or edited, default time is TZ='Europe/Lisbon';

. if issues connecting to VPN after first installation/OS upgrade, reboot;

. if DNS issues in Debian/Ubuntu/Parrot right at the start of the install, reboot and (re)start installation;

. If asking to install software, most of the time, either CShell daemon is not up, or firefox policy was not installed or Firefox is a snap. do ./vpn.sh start *and* visit https://localhost:14186/id


COMPATIBILITY
=============

Tested with chroot Debian Bullseye 11 (32 bits)

Tested with 64-bits hosts:

Debian based
============ 

Debian 10 Buster

Debian 11 Bullseye

Debian Bookworm (testing 12)

antiX-21 Grup Yorum

Devuan Chimaera 4.0

Ubuntu LTS 18.04 Bionic Beaver

Ubuntu LTS 20.04 Focal Fossa

Ubuntu LTS 22.04 Jammy Jellyfish

Voyager 22.04 LTS

Mint   20.2 Uma

Pop!_OS 22.04 LTS

Kubuntu 22.04 LTS

lubuntu 22.04 LTS

Lite 6.0 Fluorite

Kali 2022.2

Parrot 5.0.1 Electro Ara

Elementary OS 6.1 Jolnir

Deepin 20.6

KDE neon 5.25

Zorin OS 16.1

Kaisen Linux 2.1

Pardus 21.2 Yazılım Merkezi

MX 21.1 Wildflower

Peppermint OS 2022-05-22

RedHat based
============

RHEL 9.0 Plow

EuroLinux 9.0

Fedora 23

Fedora 36

CentOS 8

Rocky 8.6 Green Obsidian

Oracle 8.6

Oracle 9.0

CentOS 9 stream

AlmaLinux 9.0 Emerald Puma

Mageia 8 mga8

Arch based
==========

Arch Linux 2022.05.01

Manjaro 21.2.6.1

EndeavourOS 2022.06.32

Arco Linux 22.06.07

Garuda Linux 220614

SUSE
====

openSUSE Leap 15.3

openSUSE Leap 15.4

SLES 15-SP4

Void Linux
==========

Void Linux 2021-09-30

Gentoo
======

Gentoo Base System release 2.8

Redcore Linux 2102

Slackware
=========

Slackware 15.0

Slackware 15.1-current

Salix OS xfce 15.0

