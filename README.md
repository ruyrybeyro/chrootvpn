# chrootvpn  

Checkpoint R80+ VPN client chroot wrapper

VPN client chroot'ed Debian setup/wrapper 

for Debian/Ubuntu/RedHat/CentOS/Fedora/Arch/SUSE/Gentoo/Slackware based hosts

Checkpoint R80.10 and up

https://github.com/ruyrybeyro/chrootvpn

Rui Ribeiro 2022, Tiago Teles - Contributions for Arch Linux

This script downloads Mobile Access Portal Agent (CShell) and SSL Network Extender (SNX) installations scripts from the firewall/VPN we intend to connect, and installs them.

Being SNX still a 32-bits binary together with the multiples issues of satisfying cshell_install.sh requirements, a chroot is used in order to not to corrupt (so much) the Linux desktop of the user, and yet still tricking snx / cshell_install.sh into "believing" all the requirements are satisfied; e.g. both SNX and CShell behave on odd ways ; furthermore, Fedora and others already deprecated needed packages for SNX ; the chroot is built to counter some of those behaviours and provide a more secure setup.

The script supports several Linux distributions as the host OS, still uses Debian 11 for the chroot "light container".
The SNX binary and the CShell agent/daemon both install and run under chrooted  Debian. The Linux host runs firefox (or other browser). 

resolv.conf, VPN IP address and  routes "bleed" from the chroot directories and kernel shared with the host to the host Linux OS.

The Mobile Access Portal Agent, unlike the ordinary cshell_install.sh official setup, runs with its own non-privileged user which is different than the logged in user.

As long the version of the Debian/RedHat/SUSE/Arch distribution is not at the EOL stage, chances are very high the script will run sucessfully. Void, Gentoo and Slackware variants are not so throughly tested. See end of this document for the more than 100 recent versions/distributions successfully tested.

INSTRUCTIONS
============

Please fill up VPN and VPNIP before using this script.
SPLIT might or not have to be filled, depending on your needs and Checkpoint VPN routes.

if /opt/etc/vpn.conf is present the above script settings will be ignored. vpn.conf is created upon first instalation.

- first time, if filled VPN, VPNIP inside the script run it as 

	
	./vpn.sh -i

Otherwise, run it as:

        ./vnp.sh -i --vpn=FQDN_DNS_name_of_VPN
	

- accept localhost certificate in brower if not Firefox or if Firefox is a snap

	https://localhost:14186/id 

- visit VPN page for logging in 

CShell CheckPoint Java agent needs Java (already in the chroot)  *and* X11 desktop rights binary SNX VPN client needs a 32-bits environment.

Recommended having Firefox already installed, for deploying via this script a firefox policy for the self-signed Mobile Access Portal Agent X.509 certificate.

Usage:

vpn.sh [-c DIR|--chroot=DIR][--proxy=proxy_string][--vpn=FQDN][--oldjava] -i|--install

vpn.sh [-o FILE|--output=FILE][-c|--chroot=DIR] start|stop|restart|status

vpn.sh [-c DIR|--chroot=DIR] uninstall

vpn.sh [-o FILE|--output=FILE] disconnect|split|selfupdate|fixdns

vpn.sh -h|--help

vpn.sh -v|--version

|Option       |Function                                               |
|-------------|-------------------------------------------------------|
|-i --install |install mode - creates chroot                          |
|-c --chroot????|changes default chroot /opt/chroot directory           |
|-h --help????????|shows this help                                        |
|-v --version |script version                                         |
|--vpn        |selects VPN DNS full name at install time              |
|--proxy      |proxy to use in apt inside chroot 'http://user:pass@IP'|
|-o --output  |redirects ALL output for FILE                          |
|-s --silent????|special case of output, no arguments                   |
|--oldjava    |JDK 8 for connecting to old Checkpoint VPN servers (*) |

(*) (circa 2019) *experimental* -- not sure it is needed 

|Command      |Function                                               |
|-------------|-------------------------------------------------------|
|start????????????????|starts CShell daemon                                   |
|stop??????????????????|stops  CShell daemon                                   |
|restart????????????|restarts CShell daemon                                 |
|status??????????????|checks if CShell daemon is running                     |
|disconnect??????|disconnects VPN/SNX session from the command line      |
|split????????????????|split tunnel VPN - use only after session is up        |
|uninstall????????|deletes chroot and host file(s)                        |
|selfupdate??????|self updates this script if new version available      |
|fixdns??????????????|tries to fix resolv.conf                               |

For debugging/maintenance:

vpn.sh -d|--debug
vpn.sh [-c DIR|--chroot=DIR] shell|upgrade

vpn.sh shell

|Options      |Function                                               |
|-------------|-------------------------------------------------------|
|-d --debug??????|bash debug mode on                                     |
|shell????????????????|bash shell inside chroot                               |
|upgrade????????????|OS upgrade inside chroot                               |

This script can be downloaded running:

- git clone https://github.com/ruyrybeyro/chrootvpn/blob/main/vpn.sh
- wget https://raw.githubusercontent.com/ruyrybeyro/chrootvpn/main/vpn.sh
- curl https://raw.githubusercontent.com/ruyrybeyro/chrootvpn/main/vpn.sh -O

KNOWN FEATURES
==============

. The user installing/running the script has to got sudo rights (for root);

. For the CShell daemon to start automatically upon the user XDG login, the user has to be able to sudo /usr/local/bin/vpn.sh *without* a password;

. The CShell daemon writes over X11; if VPN is not working when called/installed from an ssh session, or after logging in, start/restart the script using a X11 graphical terminal;

. The script/chroot is not designed to allow automatic remote deploying of new versions of both CShell (or SNX?)-aparently this functionality is not supported for Linux clients. If the status command of this script shows new versions, uninstall and install it again;

. For (re)installing newer versions of SNX/CShell delete the chroot with vpn.sh uninstall and vpn -i again ; the configuration are saved in /opt/etc/vpn.conf, vpn -i is enough;

. The CShell daemon runs with a separate non-privileged user, and not using the logged in user;

. if using Firefox, is advised to have it installed *before* running this script;

. if Firefox is reinstalled, better uninstall and (re)install it, for the certificate policy file be deployed again;

. if TZ is not set before the script or edited, default time is TZ='Europe/Lisbon';

. if issues connecting to VPN after first installation/OS upgrade, reboot;

. if DNS issues in Debian/Ubuntu/Parrot right at the start of the install, reboot and (re)start installation;

. If asking to install software, most of the time, either CShell daemon is not up, or firefox policy was not installed or Firefox is a snap. do ./vpn.sh start *and* visit https://localhost:14186/id

. Linux rolling releases distributions have to be full up to date before installing any new packages. Bad things can happen and will happen running this script if packages are outdated;

. At least Arch after updates seems ocasionally needs a reboot for the VPN to work.

SCREENS
=======

The following screens show actions to be performed *after* running the script.

1. Accepting localhost certificate in Firefox at https://localhost:14186/id IF a policy not applied. This is done only *once* in the browser after each chroot (re)installation.

If the certificate is not accepted manually or via a policy, Mobile Portal will complain about lack of installed software, whether CShell and SNX are running or not.

![This is an image](/assets/images/01.png)
![This is an image](/assets/images/02.png)

2. Logging in into Mobile Portal VPN. If using a double factor auth PIN, write the regular password followed by the PIN.

![This is an image](/assets/images/03.png)

Select "Continue sign in" and "Continue" if logged in in other device/software.

![This is an image](/assets/images/04.png)

First time logging in, select Settings:

![This is an image](/assets/images/05.png)

And: "automatically" and "Network mode". This only needs to be done ONCE, the first time you login into the Mobile Portal.

![This is an image](/assets/images/06.png)

Then press Connect to connect to the firewall.

![This is an image](/assets/images/07.png)

The negotiation of a connection can take a (little) while.

![This is an image](/assets/images/08.png)

First and each time after reinstalling the chroot/script, "Trust server" has to be selected.

![This is an image](/assets/images/09.png)

The signature has to be accepted too. It can happen several times if there is a cluster solution.

![This is an image](/assets/images/10.png)

Finally the connection is established. The user will be disconnected then upon timeout, closing the tab/browser, or pressing Disconnect.

![This is an image](/assets/images/11.png)

COMPATIBILITY
=============

Tested with chroot Debian Bullseye 11 (32 bits - i386)

Tested the following x86_64 hosts:

Debian based
============

Debian 10 Buster

Debian 11 Bullseye

Debian Edu 11.3

Debian Bookworm (testing 12)

antiX-21 Grup Yorum

Devuan Chimaera 4.0

Ubuntu LTS 18.04 Bionic Beaver

Ubuntu LTS 20.04 Focal Fossa

Ubuntu LTS 22.04 Jammy Jellyfish

Mint   20.2 Uma

Mint   21 Vanessa

Voyager 22.04 LTS

Pop!_OS 22.04 LTS

Greenie Linux 20.04

Kubuntu 20.04 LTS

Kubuntu 22.04 LTS

Lubuntu 20.04 LTS

Lubuntu 22.04 LTS

Xubuntu 20.04 LTS

Xubuntu 22.04 LTS, Jammy Jellyfish

Ubuntu Budgie 22.04

Ubuntu Mate 20.04.4 LTS

Ubuntu Mate 22.04 LTS

Runtu 20.04.1

Runtu 22.04

Feren OS 2022.04

Lite 6.0 Fluorite

Kali 2022.2

Parrot 5.0.1 Electro Ara

Elementary OS 6.1 Jolnir

Deepin 20.6

ExTix Deepin 22.6/20.6

KDE neon 5.25

Zorin OS 16.1

Kaisen Linux 2.1

Pardus 21.2 Yaz??l??m Merkezi

MX 21.1 Wildflower

Peppermint OS 2022-05-22

Drauger OS 7.6 Strigoi

Trisquel 10.0.1 Nabia

Freespire 82

SharkLinux

Bodhi Linux 6.0.0

MakuluLinux Shift 2022-06.10

Condres OS 1.0

Emmabunt??s DE 4

Neptune 7 ("Faye")

LinuxFx 11

PureOS 10.0 (Byzantium)

SolydXK10

HamoniKR 5.0 Hanla

Lliurex 21

Elive 3.8.30

B2D/OB2D ?????? Linux ?????? 2023 1.0.1

BunsenLabs Linux 10.5 (Lithium)

BOSS 9 (urja)

Netrunner 21.01 (???XOXO???)

Q4OS 4.8 Gemini

Kanotix64 Silverfire 

cutefishOS

SparkyLinux 7 (Orion-Belt) 2022.7

Septor 2022

Pearl MATE Studio 11

MAX-11.5 (MAdrid_linuX)

RedHat based
============

RHEL 9.0 Plow

EuroLinux 8.6 Kyiv

EuroLinux 9.0

Springale Open Enterprise Linux 9.0 (Parma)

Fedora 23

Fedora 36

Network Security Toolkit (NST) 36

CentOS 8

CentOS 9 stream

Rocky 8.6 Green Obsidian

Rocky 9.0 Blue Onyx

Oracle 8.6

Oracle 9.0

AlmaLinux 9.0 Emerald Puma

Mageia 8 mga8

ROSA Fresh Desktop 12.2

Mandrake/Mandriva/RedHat based
==============

ALT k Linux 10.0

OpenMandriva Lx 4.3

Arch based
==========

Arch Linux 2022.05.01

Manjaro 21.2.6.1

EndeavourOS 2022.06.32

Arco Linux 22.06.07

Garuda Linux 220614

Mabox Linux 22.06

BluestarLinux 5.1

Archcraft 2022.06.08

ArchLabs

ArchMan 2022.07.02

ArchBang 2022.07.02

SalientOS 21.06

RebornOS

ArchEx Build 220206

Peux OS 22.06

AmOs Linux

AaricKDE

SUSE
====

SLES 15-SP4

openSUSE Leap 15.3

openSUSE Leap 15.4

Linux Kamarada 15.3

GeckoLinux STATIC Cinnamon 153.x

Regata OS 22 Discovery

Void Linux
==========

Void Linux 2021-09-30

AgarimOS

Gentoo
======

Gentoo Base System release 2.8

Redcore Linux 2102

Calculate Linux 22.0.1

Slackware
=========

Slackware 15.0

Slackware 15.1-current

Salix OS xfce 15.0

Relevant CheckPoint Linux support pages
=======================================

SSL Network Extender https://supportcenter.checkpoint.com/supportcenter/portal?eventSubmit_doGoviewsolutiondetails=&solutionid=sk65210#Linux%20Supported%20Platforms

How to install SSL Network Extender (SNX) client on Linux machines https://supportcenter.checkpoint.com/supportcenter/portal?eventSubmit_doGoviewsolutiondetails=&solutionid=sk114267

Mobile Access Portal Agent Prerequisites for Linux https://supportcenter.checkpoint.com/supportcenter/portal?eventSubmit_doGoviewsolutiondetails=&solutionid=sk119772

Mobile Access Portal and Java Compatibility https://supportcenter.checkpoint.com/supportcenter/portal?eventSubmit_doGoviewsolutiondetails=&solutionid=sk113410

Mobile Access Portal Agent for Mozilla Firefox asks to re-install even after it was properly installed https://supportcenter.checkpoint.com/supportcenter/portal?eventSubmit_doGoviewsolutiondetails=&solutionid=sk122576&partition=Advanced&product=Mobile

