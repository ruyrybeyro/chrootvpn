#!/usr/bin/env bash
#
# Rui Ribeiro
#
# VPN client chroot'ed setup/wrapper for Debian/Ubuntu/RH/CentOS/Fedora/SUSE hosts 
# Checkpoint R80.10 and up
#
# Please fill VPN and VPNIP before using this script.
# SPLIT might or not have to be filled, depending on your needs 
# and Checkpoint VPN given routes.
#
# if /opt/etc/vpn.conf is present the above script settings will be 
# ignored. vpn.conf is created upon first instalation.
#
# first time run it as ./vpn.sh -i --vpn=YOUR.VPN.SERVER
# Accept localhost certificate visiting https://localhost:14186/id if not Firefox
# Then open VPN URL to login/start the VPN
#
# It will get CShell and SNX installations scripts from the firewall,
# and install them. 
#
# vpn.sh selfupdate 
# might update this script if new version+Internet connectivity available
#
# non-chroot version not written intencionally. 
# SNX/CShell behave on odd ways ;
# the chroot is built to counter some of those behaviours
#
# CShell CheckPoint Java agent needs Java *and* X11 desktop rights
# binary SNX VPN client needs 32-bits environment
#
# tested with chroot Debian Bullseye 11 (32 bits) and
# 64 bits hosts: 
#        Debian 10 
#        Debian 11 
#        Debian Bookworm (testing 12)
#        antiX-21
#        Devuan Chimaera 4.0
#        Ubuntu LTS 18.04 
#        Ubuntu LTS 22.04 
#        Voyager 22.04 LTS
#        Mint   20.2
#        Pop!_OS 22.04 LTS
#        Kubuntu 22.04 LTS
#        lubuntu 22.04 LTS
#        Lite 6.0
#        Kali 2022.2
#        Parrot 5.0.1 Electro Ara
#        Elementary OS 6.1 Jolnir
#        Deepin 20.6
#        KDE neon 5.25
#        Zorin OS 16.1
#        Kaisen Linux 2.1
#        Pardus 21.2
#        MX 21.1 Wildflower
#        Peppermint OS 2022-05-22
#        RHEL 9.0
#        EuroLinux 9.0
#        Fedora 23 
#        Fedora 36
#        Rocky  8.6
#        CentOS 8 Stream
#        CentOS 9 Stream
#        AlmaLinux 9.0
#        Mageia 8
#        Oracle Linux 8.6
#        Oracle Linux 9.0
#        Arch Linux 2022.05.01
#        Manjaro 21.2.6.1
#        EndeavourOS 2022.06.32
#        Arco Linux 22.06.07
#        Garuda Linux 220614
#        openSUSE Leap 15.3
#        openSUSE Leap 15.4
#        SLES 15-SP4
#        Void Linux 
#        Gentoo 2.8
#        Redcore Linux 2102
#        Slackware 15.0
#        Slackware 15.1-current
#        Salix OS xfce 15.0
#
# For DNS sync between host and chroot
# "Debian" host resolvconf       and /run/resolvconf/resolv.conf
# "Arch"   host openresolv       and /run/resolvconf/interfaces/NetworkManager
# "Void"   host openresolv       and /run/NetworkManager/resolv.conf
# "RedHat" host systemd-resolved and /run/systemd/resolve/stub-resolv.conf
# "SUSE"   host dnsmasq          and /run/netconfig/resolv.conf
#

# script/deploy version, make the same as deploy
VERSION="v1.60"

# default chroot location (700 MB needed - 1.5GB while installing)
CHROOT="/opt/chroot"

# default configuration file
# created first time upon successful setup/run
# so vpn.sh can be successfuly replaced by new versions
# or reinstalled from scratch
CONFFILE="/opt/etc/vpn.conf"

# if vpn.conf present, source VPN, VPNIP, SPLIT and SSLVPN from it
[[ -f "${CONFFILE}" ]] && . "${CONFFILE}"

# Sane defaults:
 
# Checkpoint VPN address
# selfupdate brings them from the older version
# Fill VPN *and* VPNIP *before* using the script
# if filling in keep the format
# values used first time installing, 
# otherwise /opt/etc/vpn.conf overrides them
[[ -z "$VPN" ]] && VPN=""
[[ -z "$VPNIP" ]] && VPNIP=""

# split VPN routing table if deleting VPN gateway is not enough
# selfupdate brings it from the older version
# if empty script will delete VPN gateway
# if filling in keep the format
# value used first time installing, 
# otherwise /opt/etc/vpn.conf overrides it
[[ -z "$SPLIT" ]] && SPLIT=""

# we test / and sslvnp SSL VPN portal PATHs.
# Change here for a custom PATH
[[ -z "$SSLVPN" ]] && SSLVPN="sslvpn"

# OS to deploy inside 32-bit chroot  
# minimal Debian
VARIANT="minbase"
RELEASE="bullseye" # Debian 11
DEBIANREPO="http://deb.debian.org/debian/" # fastly repo

# github repository for selfupdate command
# https://github.com/ruyrybeyro/chrootvpn
GITHUB_REPO="ruyrybeyro/chrootvpn"

# used during initial chroot setup
# for chroot shell correct time
# if TZ is empty
# set TZ before first time creating chroot
[[ -z "${TZ}" ]] && TZ='Europe/Lisbon'

# URL for testing if split or full VPN
URL_VPN_TEST="https://www.debian.org"

# CShell writes on the X11 display
[[ -z "${DISPLAY}" ]] && export DISPLAY=":0.0"

# dont bother with locales
# all on plain English
export LC_ALL=C LANG=C

# script full PATH
SCRIPT=$(realpath "${BASH_SOURCE[0]}")

# script name
SCRIPTNAME=$(basename "${SCRIPT}")

#  preserve program passed arguments $@ into a BASH array
args=("$@")

# VPN interface created by SNX
TUNSNX="tunsnx"

# xdg autostart X11 file
XDGAUTO="/etc/xdg/autostart/cshell.desktop"

# script PATH upon successful setup
INSTALLSCRIPT="/usr/local/bin/${SCRIPTNAME}"

# cshell user
CSHELL_USER="cshell"
CSHELL_UID="9000"
CSHELL_GROUP="${CSHELL_USER}"
CSHELL_GID="9000"
CSHELL_HOME="/home/${CSHELL_USER}"

# "booleans"
true=0
false=1

# PATH for being called outside the command line (from xdg)
PATH="/sbin:/usr/sbin:/bin:/usr/sbin:${PATH}"

# Java version (affected by oldjava parameter) 
# for old CheckPoint VPN servers
# circa 2019?
# hint:
# The web Portal Interface has a far more dated look than in 2022
#
# seems not to be needed, who will stay here for now
JAVA8=false

#
# user interface handling
#
# -h|--help
#

do_help()
{
   # non documented options
   # vpn.sh --osver    showing OS version

   cat <<-EOF1
	VPN client setup for Debian/Ubuntu
	Checkpoint R80.10+	${VERSION}

	${SCRIPTNAME} [-c DIR|--chroot=DIR][--proxy=proxy_string][--vpn=FQDN] -i|--install
	${SCRIPTNAME} [-o FILE|--output=FILE][-c DIR|--chroot=DIR] start|stop|restart|status
	${SCRIPTNAME} [-c DIR|--chroot=DIR] uninstall
	${SCRIPTNAME} [-o FILE|--output=FILE] disconnect|split|selfupdate|fixdns
	${SCRIPTNAME} -h|--help
	${SCRIPTNAME} -v|--version
	
	-i|--install install mode - create chroot
	-c|--chroot  change default chroot ${CHROOT} directory
	-h|--help    show this help
	-v|--version script version
	--vpn        select VPN DNS full name install time
	--oldjava    JDK 8 for connecting to old Checkpoint VPN servers (circa 2019) *experimental*
	--proxy      proxy to use in apt inside chroot 'http://user:pass@IP'
	--portalurl  custom VPN portal URL prefix (usually sslvpn) ;
                     use it as --portalurl=STRING together with --install
	-o|--output  redirect ALL output for FILE
	-s|--silent  special case of output, no arguments
	
	start        start    CShell daemon
	stop         stop     CShell daemon
	restart      restart  CShell daemon
	status       check if CShell daemon is running
	disconnect   disconnect VPN/SNX session from the command line
	split        split tunnel VPN - use only after session is up
	uninstall    delete chroot and host file(s)
	selfupdate   self update this script if new version available
	fixdns       try to fix resolv.conf
	
	For debugging/maintenance:
	
	${SCRIPTNAME} -d|--debug
	${SCRIPTNAME} [-c DIR|--chroot=DIR] shell|upgrade
	
	-d|--debug   bash debug mode on
	shell        bash shell inside chroot
	upgrade      OS upgrade inside chroot
	
	URL for accepting CShell localhost certificate 
	https://localhost:14186/id

	EOF1

   # exits after help
   exit 0
}


# complain to STDERR and exit with error
die() 
{
   # calling function name: message 
   echo "${FUNCNAME[2]}->${FUNCNAME[1]}: $*" >&2 

   exit 2 
}  


# DNS lookup: getent is installed by default
vpnlookup()
{
   # resolve IPv4 IP address of DNS name $VPN
   VPNIP=$(getent ahostsv4 "${VPN}" | awk 'NR==1 { print $1 } ' )
   [[ -z "${VPNIP}" ]] && die "could not resolve ${VPN} DNS name"
}


# optional arguments handling
needs_arg() 
{ 
   [[ -z "${OPTARG}" ]] && die "No arg for --$OPT option"
}


# Redirect Output
# -o|--output
# -s|--silent called with /dev/null
#
doOutput()
{
   LOG_FILE="$1"

   # Close standard output file descriptor
   exec 1<&-
   # Close standard error file descriptor
   exec 2<&-

   # Open standard output as LOG_FILE for read and write.
   exec 1<> "${LOG_FILE}"

   # Redirect standard error to standard output
   exec 2>&1
}


# arguments - script getopts options handling
doGetOpts()
{
   # install status flag
   install=false

   # process command line options
   while getopts dic:-:o:shv OPT
   do

      # long option -- , - handling
      # reformulate OPT and OPTARG
      # arguments are
      # OPT equals name of long options
      # = separator/delimiter
      # OPTARG argument
      # as in --vpn=myvpn.myorg.com
      # OPT=vpn
      # OPTARG=myvpn.myorg.com
      #
      if [[ "${OPT}" = "-" ]]
      then   
         OPT=${OPTARG%%=*}       # extract long option name
         OPTARG=${OPTARG#"$OPT"} # extract long option argument (may be empty)
         OPTARG=${OPTARG#=}      # if long option argument, remove assigning `=`
      fi

      # handle normal or long option
      case "${OPT}" in

         i | install )     install=true ;;           # install chroot
         c | chroot )      needs_arg                 # change location of change on runtime 
                           CHROOT="${OPTARG}" ;;
         vpn )             needs_arg                 # use other VPN on runtime
                           VPN="${OPTARG}" 
                           vpnlookup ;;
         proxy )           needs_arg                 # APT proxy inside chroot
                           CHROOTPROXY="${OPTARG}" ;;
         portalurl )       needs_arg                 # VPN portal URL prefix
                           SSLVPN="${OPTARG}" ;;
         oldjava )         JAVA8=true ;;             # compatibility with older VPN servers
         v | version )     echo "${VERSION}"         # script version
                           exit 0 ;;
         osver)            awk -F"=" '/^PRETTY_NAME/ { gsub("\"","");print $2 } ' /etc/os-release
                           exit 0 ;;
         o | output )      needs_arg
                           doOutput "${OPTARG}" ;;
         s | silent )      doOutput "/dev/null" ;;
         d | debug )       set -x ;;                 # bash debug on
         h | help )        do_help ;;                # show help
         ??* )             die "Illegal option --${OPT}" ;;  # bad long option
         ? )               exit 2;;                  # bad short option (reported by getopts) 

       esac

   done
}


# minimal requirements check
PreCheck()
{
   # If not Intel based
   if [[ "$(uname -m)" != 'x86_64' ]] && [[ "$(uname -m)" != 'i386' ]]
   then
      die "This script is for Debian/RedHat/Arch/SUSE/Gentoo/Slackware/Void/Deepin Linux Intel based flavours only"
   fi

   # init distro flags
   DEB=0
   RH=0
   ARCH=0
   SUSE=0
   GENTOO=0
   SLACKWARE=0
   VOID=0
   DEEPIN=0

   if [[ -f "/etc/debian_version" ]]
   then
      DEB=1 # is Debian family
      ischroot && die "Do not run this script inside a chroot"
      [[ -f "/etc/os-version" ]] && [[ $(awk -F= '/SystemName=/ { print $2 } ' /etc/os-version) == Deepin ]] && DEEPIN=1
   fi
   [[ -f "/etc/redhat-release" ]]    && RH=1     # is RedHat family 
   [[ -f "/etc/arch-release" ]]      && ARCH=1   # is Arch family
   [[ -f "/etc/SUSE-brand" ]]        && SUSE=1   # is SUSE family
   [[ -f "/etc/gentoo-release" ]]    && GENTOO=1 # is GENTOO family
   [[ -f "/etc/redcore-release" ]]   && GENTOO=1 # is GENTOO family
   [[ -f "/etc/slackware-version" ]] && SLACKWARE=1 # is Slackware
   [[ -f "/etc/os-release" ]] && [[ $(awk -F= ' /^DISTRIB/ { gsub("\"", ""); print $2 } ' /etc/os-release) == void ]] && VOID=1 # Void Linux
  
   # if none of distrubition families above, abort 
   [[ "${DEB}" -eq 0 ]] && [[ "${RH}" -eq 0 ]] && [[ "${ARCH}" -eq 0 ]] && [[ "${SUSE}" -eq 0 ]] && [[ "${GENTOO}" -eq 0 ]] && [[ "${SLACKWARE}" -eq 0 ]] && [[ "${VOID}" -eq 0 ]] && die "Only Debian, RedHat ArchLinux, SUSE, Gentoo, Slackware and Void family distributions supported"

   # if VPN or VPNIP empty, abort
   if [[ -z "${VPN}" ]] || [[ -z "${VPNIP}" ]] 
   then
      # and not handling uninstall, abort
      [[ "$1" == "uninstall" ]] || die "Run vpn.sh -i --vpn=FQDN or fill in VPN and VPNIP with the DNS FQDN and the IP address of your Checkpoint VPN server"
   fi

   # This script needs a user with sudo privileges
   which sudo &>/dev/null || die "please install and configure sudo for this user"

   # for using/relaunching
   # self-promoting script to sudo
   # recursively call the script with sudo
   # hence no needing sudo before the command
   [[ "${EUID}" -ne 0 ]] && exec sudo "$0" "${args[@]}" 
}


# wrapper for chroot
doChroot()
{
   # setarch i386 lies to uname about being 32 bits
   setarch i386 chroot "${CHROOT}" "$@"
}


# C/Unix convention - 0 success, 1 failure
isCShellRunning()
{
   pgrep -f CShell &> /dev/null
   return $?
}


# mount Chroot filesystems
mountChrootFS()
{
   # if CShell running, they are mounted
   if ! isCShellRunning
   then

      # mount chroot filesystems
      # if not mounted
      mount | grep "${CHROOT}" &> /dev/null
      if [[ $? -eq 1 ]]
      then
         # consistency checks
         [[ ! -f "${CHROOT}/etc/fstab" ]] && die "no ${CHROOT}/etc/fstab"

         # mount using fstab inside chroot, all filesystems
         mount --fstab "${CHROOT}/etc/fstab" -a

        # /run/nscd cant be shared between host and chroot
        # for it to not share socket
        if [[ -d /run/nscd ]]
        then
           mkdir -p "${CHROOT}/nscd"
           mount --bind "${CHROOT}/nscd" "${CHROOT}/run/nscd"
        fi

         # lax double check
         mount | grep "${CHROOT}" &> /dev/null
         if [[ $? -ne 0 ]]
         then
            die "mount failed"
         fi
      fi

   fi
}


# umount chroot fs
umountChrootFS()
{
   # unmount chroot filesystems
   # if mounted
   if mount | grep "${CHROOT}" &> /dev/null
   then

      # there is no --fstab for umount
      # we dont want to abort if not present
      [[ -f "${CHROOT}/etc/fstab" ]] && doChroot /usr/bin/umount -a 2> /dev/null
         
      # umount any leftover mount
      for i in $(mount | grep "${CHROOT}" | awk ' { print  $3 } ' )
      do
         umount "$i" 2> /dev/null
         umount -l "$i" 2> /dev/null
      done

      # force umount any leftover mount
      for i in $(mount | grep "${CHROOT}" | awk ' { print  $3 } ' )
      do
         umount -l "$i" 2> /dev/null
      done
   fi
}

# Firefox Policy
# add X.509 self-signed CShell certificate
# to the list of accepted enterprise root certificates
FirefoxJSONpolicy()
{
   cat <<-EOF14 > "${DIR}/policies.json"
	{
	   "policies": {
	               "ImportEnterpriseRoots": true,
	               "Certificates": {
	               "Install": [
	                          "${CHROOT}/usr/bin/cshell/cert/CShell_Certificate.crt"
	                          ]
	                               }
	               }
	}
	EOF14
}


# install Firefox policy accepting
# CShell localhost certificate
# in the host machine
FirefoxPolicy()
{
   local DIR
   local PolInstalled

   # flag as not installed
   PolInstalled=0

   if [[ "$1" == "install" ]]
   then
      [[ ${VOID} -eq 1 ]] && mkdir "/usr/lib/firefox/distribution"
      [[ ${SLACKWARE} -eq 1 ]] && mkdir "/usr/lib64/firefox/distribution" 2> /dev/null
   fi

   # if Firefox installed
   # cycle possible firefox global directories
   for DIR in "/etc/firefox/policies/" $(find /usr/lib/*firefox*/distribution /usr/lib64/*firefox*/distribution /usr/share/*firefox*/distribution /opt/*firefox*/distribution -type d 2> /dev/null)
   do
      if  [[ "$1" == "install" ]] && [[ -d "${DIR}" ]]
      then
         # if policies file not already installed
         if [[ ! -f "${DIR}/policies.json" ]] || grep CShell_Certificate "${DIR}/policies.json" &> /dev/null
         then

            # can't be sure for snap
            # so don't flag as policy installed
            # for it to warn for accepting certificate
            if [[ "${DIR}" != "/etc/firefox/policies/" ]]
            then
               # flag as installed
               PolInstalled=1
            fi

            # create JSON policy file
            # Accepting CShell certificate
            FirefoxJSONpolicy

         else
            echo "Another policy already found at ${DIR}." >&2
         fi
      fi

      # delete Firefox policy for accepting localhost CShell certificate
      if [[ "$1" == "uninstall" ]] && grep CShell_Certificate "${DIR}/policies.json" &> /dev/null
      then
         rm -f "${DIR}/policies.json"
      fi

   done

   # if Firefox policy installed
   # "install" implied, Pollinstalled cant be 1 otherwise
   if [[ "$PolInstalled" -eq 1 ]]
   then
      # if Firefox running, kill it
      pgrep -f firefox &>/dev/null && pkill -9 -f firefox

      echo "Firefox policy created for accepting https://localhost:14186 certificate" >&2
      echo "If using other browser than Firefox or Firefox is a snap" >&2
   fi
}

#
# Client wrapper section
#

# split command
#
# split tunnel, only after VPN is up
# if VPN is giving "wrong routes"
# deleting the default VPN gateway mith not be enough
# so there is a need to fill in routes in the SPLIT variable
# at /opt/etc/vpn.conf 
# or if before install it, at the beginning of this script
#
Split()
{
   # if SPLIT empty
   if [[ -z "${SPLIT+x}" ]]
   then
      echo "If this does not work, please fill in SPLIT with a network/mask list eg x.x.x.x/x x.x.x.x/x" >&2
      echo "either in ${CONFFILE} or in ${SCRIPTNAME}" >&2

      # delete default gw into VPN
      ip route delete 0.0.0.0/1
      echo "default VPN gateway deleted" >&2
   else 
      # get local VPN given IP address
      IP=$(ip -4 addr show "${TUNSNX}" | awk '/inet/ { print $2 } ')

      # clean all VPN routes
      # clean all routes given to tunsnx interface
      ip route flush table main dev "${TUNSNX}"

      # create new VPN routes according to $SPLIT
      # don't put ""
      for i in ${SPLIT}
      do
         ip route add "$i" dev "${TUNSNX}" src "${IP}"
      done
   fi
}


# status command
showStatus()
{  
   local VER

   if ! isCShellRunning
   then
      # chroot/mount down, etc, not showing status
      die "CShell not running"
   else
      echo "CShell running" 
   fi

   # host / chroot arquitecture
   echo
   echo -n "System: "
   awk -v ORS= -F"=" '/^PRETTY_NAME/ { gsub("\"","");print $2" " } ' /etc/os-release
   #arch
   echo -n "$(uname -m) "
   uname -r

   echo -n "Chroot: "
   doChroot /bin/bash --login -pf <<-EOF2 | awk -v ORS= -F"=" '/^PRETTY_NAME/ { gsub("\"","");print $2" " } '
	cat /etc/os-release
	EOF2

   # print--architecture and not uname because chroot shares the same kernel
   doChroot /bin/bash --login -pf <<-EOF3
	/usr/bin/dpkg --print-architecture
	EOF3

   # SNX version
   echo
   echo -n "SNX - installed              "
   doChroot snx -v 2> /dev/null | awk '/build/ { print $2 }'
   
   echo -n "SNX - available for download "
   if ! wget -q -O- --no-check-certificate "https://${VPN}/SNX/CSHELL/snx_ver.txt" 2> /dev/null
   then
      wget -q -O- --no-check-certificate "https://${VPN}/${SSLVPN}/SNX/CSHELL/snx_ver.txt" 2> /dev/null || echo "Could not get SNX download version" >&2
   fi

   # Mobile Access Portal Agent version installed
   # we kept it earlier when installing
   echo
   if [[ -f "${CHROOT}/root/.cshell_ver.txt" ]]
   then
      echo -n "CShell - installed version      "
      cat "${CHROOT}/root/.cshell_ver.txt"
   fi

   echo -n "CShell - available for download "
   if ! wget -q -O- --no-check-certificate "https://${VPN}/SNX/CSHELL/cshell_ver.txt" 2> /dev/null
   then
      wget -q -O- --no-check-certificate "https://${VPN}/${SSLVPN}/SNX/CSHELL/cshell_ver.txt" 2> /dev/null || echo "Could not get CShell download version" >&2
   fi

   # Mobile Access Portal Agent X.509 self-signed CA certificate
   if [[ -f "${CHROOT}/usr/bin/cshell/cert/CShell_Certificate.crt" ]]
   then
      echo
      echo "CShell self-signed CA certificate"
      echo
      openssl x509 -in "${CHROOT}/usr/bin/cshell/cert/CShell_Certificate.crt" -text | grep -E ", CN = |  Not [BA]"
   fi

   # show vpn.conf
   echo
   [[ -f "${CONFFILE}" ]] && cat "${CONFFILE}"

   # IP connectivity
   echo
   # IP address VPN local address given
   IP=""
   IP=$(ip -4 addr show "${TUNSNX}" 2> /dev/null | awk '/inet/ { print $2 } ')

   echo -n "Linux  IP address: "
   # print IP address linked to hostname
   #hostname -I | awk '{print $1}'
    ip a s |
    sed -ne '
        /127.0.0.1/!{
            s/^[ \t]*inet[ \t]*\([0-9.]\+\)\/.*$/\1/p
        }
    '

   echo

   # if $IP not empty
   # e.g. VPN up
   #
   if [[ -n "${IP}" ]]
   then
      echo "VPN on"
      echo
      echo "${TUNSNX} IP address: ${IP}"

      # VPN mode test
      # a configured proxy would defeat the test, so --no-proxy
      # needs to test *direct* IP connectivity
      # OS/ca-certificates package needs to be recent
      # or otherwise, the OS CA root certificates chain file needs to be recent
      echo
      if wget -O /dev/null -o /dev/null --no-proxy "${URL_VPN_TEST}"
      then
         # if it works we are talking with the actual site
         echo "split tunnel VPN"
      else
         # if the request fails e.g. certificate does not match address
         # we are talking with the "transparent proxy" firewall site
         echo "full  tunnel VPN"
      fi
   else
      echo "VPN off"
   fi

   # VPN signature(s) - /etc/snx inside the chroot 
   echo
   echo "VPN signatures"
   echo
   bash -c "cat ${CHROOT}/etc/snx/"'*.db' 2> /dev/null  # workaround for * expansion inside sudo

   # DNS
   echo
   [[ "${RH}" -eq 1 ]] && resolvectl status
   echo
   cat /etc/resolv.conf
   echo
    
   # get latest release version of this script
   VER=$(wget -q -O- --no-check-certificate "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | jq -r ".tag_name")

   echo "current ${SCRIPTNAME} version     : ${VERSION}"

   # full VPN it might not work
   [[ "${VER}" == "null" ]] || [[ -z "${VER}" ]] || echo "GitHub  ${SCRIPTNAME} version     : ${VER}"
}


# kill Java daemon agent
killCShell()
{
   if isCShellRunning
   then

      # kill all java CShell agents (1)
      pkill -9 -f CShell 

      if ! isCShellRunning
      then
         echo "CShell stopped" >&2
      else
         # something very wrong happened
         die "Something is wrong. kill -9 did not kill CShell"
      fi

   fi
}

# fix /etc/resolv.conf links, chroot and host
# we need them ok for syncronizing chroot with host
fixLinks()
{
      if [[ -f "$1" ]]
      then
         # fix link inside chroot
         ln -sf "$1" "${CHROOT}/etc/resolv.conf"

         # if link in host deviates from needed
         readlink /etc/resolv.conf | grep "$1" &> /dev/null
         if [ $? -ne 0  ]
         then
            # fix it
            ln -sf "$1" /etc/resolv.conf
         fi
      else
         echo "if $1 does not exist, we cant use it to fix/share resolv.conf file between host and chroot" >&2
         echo "setting up chroot DNS as a copy of host" >&2
         rm -f "${CHROOT}/etc/resolv.conf"
         cat /etc/resolv.conf > "${CHROOT}/etc/resolv.conf"
      fi
}


fixDNS()
{
   # fixes potential resolv.conf/DNS issues inside chroot.
   # Checkpoint software seems not mess up with it.
   # Unless a security update inside chroot damages it

   cd /etc || die "could not enter /etc"

   if [[ "${DEEPIN}" -eq 1 ]]
   then
      fixLinks ../run/systemd/resolve/stub-resolv.conf
   else
      # Debian family - resolvconf
      [[ "${DEB}" -eq 1 ]] && fixLinks ../run/resolvconf/resolv.conf
   fi

   # ArchLinux family - openresolv
   [[ "${ARCH}" -eq 1 ]] && fixLinks ../run/resolvconf/interfaces/NetworkManager

   # RH family - systemd-resolved
   [[ "${RH}" -eq 1 ]] && fixLinks ../run/systemd/resolve/stub-resolv.conf

   # SUSE - netconfig
   [[ "${SUSE}" -eq 1 ]] && fixLinks ../run/netconfig/resolv.conf

   # Void
   [[ "${VOID}" -eq 1 ]] && fixLinks ../run/NetworkManager/resolv.conf

   # Gentoo
   [[ "${GENTOO}" -eq 1 ]] && fixLinks ../run/NetworkManager/resolv.conf

   # Slackware
   [[ "${SLACKWARE}" -eq 1 ]] && fixLinks ../run/NetworkManager/resolv.conf
}

# start command
doStart()
{
   # ${CSHELL_USER} (cshell) apps - X auth
   if ! su - "${SUDO_USER}" -c "DISPLAY=${DISPLAY} xhost +local:"
   then
      echo "If there are not X11 desktop permissions, VPN won't run" >&2
      echo "run this while logged in to the graphic console," >&2
      echo "or in a terminal inside the graphic console" >&2
      echo 
      echo "X11 auth not given" >&2
      echo "Please run as the X11/regular user:" >&2
      echo "xhost +si:local:" >&2
   fi

   # fixes potential resolv.conf/DNS issues inside chroot. 
   # Checkpoint software seems not mess up with it.
   # Unless a security update inside chroot damages it

   fixDNS

   # mount Chroot file systems
   mountChrootFS

   # start doubles as restart

   # kill CShell if running
   if  isCShellRunning
   then
      # kill CShell if up
      # if CShell running, fs are mounted
      killCShell
      echo "Trying to start it again..." >&2
   fi

   # launch CShell inside chroot
   doChroot /bin/bash --login -pf <<-EOF4
	su -c "DISPLAY=${DISPLAY} /usr/bin/cshell/launcher" ${CSHELL_USER}
	EOF4

   if ! isCShellRunning
   then
      die "something went wrong. CShell daemon not launched." 
   else
      # CShell agent running, now user can authenticate
      echo "open browser at https://${VPN} to login/start  VPN" >&2
      echo >&2
      # if localhost generated certificate not accepted, VPN auth will fail
      echo "Accept localhost certificate anytime visiting https://localhost:14186/id" >&2
      echo "If it does not work, launch ${SCRIPTNAME} in a terminal from the X11 console" >&2
   fi
}

# try to fix out of sync resolv.conf
fixDNS2()
{
   # try to restore resolv.conf
   # not all configurations need action, NetworkManager seems to behave well

   [[ "${DEB}"  -eq 1 ]] && [[ "${DEEPIN}" -eq 0 ]] && resolvconf -u
   [[ "${ARCH}" -eq 1 ]] && resolvconf -u
   [[ "${VOID}" -eq 1 ]] && resolvconf -u
   [[ "${SUSE}" -eq 1 ]] && netconfig update -f
   [[ "${RH}"   -eq 1 ]] && authselect apply-changes
}


# disconnect SNX/VPN session
doDisconnect()
{
   # if snx/VPN up, disconnect
   pgrep snx > /dev/null && doChroot /usr/bin/snx -d

   # try to fix resolv.conf having VPN DNS servers 
   # after tearing down VPN connection
   fixDNS2
}


# stop command
doStop()
{
   # disconnect VPN
   doDisconnect

   # kill Checkpoint agent
   killCShell
  
   # unmount chroot filesystems 
   umountChrootFS
}


# chroot shell command
doShell()
{
   # mount chroot filesystems if not mounted
   # otherwise shell wont work well
   mountChrootFS

   # open an interactive root command line shell 
   # inside the chrooted environment
   doChroot /bin/bash --login -pf

   # dont need mounted filesystem with CShell agent down
   if ! isCShellRunning
   then
      umountChrootFS
   fi
}


# uninstall command
doUninstall()
{
   local DIR

   # stop CShell
   doStop

   # delete autorun file, chroot subdirectory, installed script and host user
   rm -f  "${XDGAUTO}"          &>/dev/null
   rm -rf "${CHROOT}"           &>/dev/null
   rm -f  "${INSTALLSCRIPT}"    &>/dev/null
   userdel -rf "${CSHELL_USER}" &>/dev/null
   groupdel "${CSHELL_GROUP}"   &>/dev/null

   # delete Firefox policies installed by this script
   FirefoxPolicy uninstall

   # leave /opt/etc/vpn.conf behind
   # for easing reinstalation
   if [[ -f "${CONFFILE}" ]]
   then
      echo "${CONFFILE} not deleted. If you are not reinstalling do:"
      echo "sudo rm -f ${CONFFILE}"
      echo
      echo "cat ${CONFFILE}"
      cat "${CONFFILE}"
      echo
   fi

   echo "chroot+checkpoint software deleted" >&2
}


# upgrade OS inside chroot
# vpn.sh upgrade option
Upgrade() {
   doChroot /bin/bash --login -pf <<-EOF12
	apt update
	apt -y upgrade
        apt -y autoremove
	apt clean
	EOF12
}


# self update this script
# vpn.sh selfupdate
selfUpdate() 
{
    # temporary file for downloading new vpn.sh    
    local vpnsh
    # github release version
    local VER

    # get this latest script release version
    VER=$(wget -q -O- --no-check-certificate "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | jq -r ".tag_name")
    echo "current version     : ${VERSION}"

    [[ "${VER}" == "null" ]] || [[ -z "${VER}" ]] && die "did not find any github release. Something went wrong"

    # if github version greater than this version
    if [[ "${VER}" > "${VERSION}" ]]
    then
        echo "Found a new version of ${SCRIPTNAME}, updating myself..."

        vpnsh="$(mktemp)" || die "failed creating mktemp file"

        # download github more recent version
        if wget -O "${vpnsh}" -o /dev/null "https://github.com/${GITHUB_REPO}/releases/download/${VER}/vpn.sh" 
        then

           # if script not run for /usr/local/bin, also update it
           [[ "${INSTALLSCRIPT}" != "${SCRIPT}"  ]] && cp -f "${vpnsh}" "${SCRIPT}"

           # update the one in /usr/local/bin
           cp -f "${vpnsh}" "${INSTALLSCRIPT}"

           chmod a+rx "${INSTALLSCRIPT}" "${SCRIPT}"
           
           # remove temporary file
           rm -f "${vpnsh}"

           echo "script(s) updated to version ${VER}"
           exit 0
        else
           die "could not fetch new version"
        fi

    else
       die "Already the latest version."
    fi
}


# check if chroot usage is sane
PreCheck2()
{
   # if setup successfully finished, launcher has to be there
   if [[ ! -f "${CHROOT}/usr/bin/cshell/launcher" ]]
   then

      # if launcher not present something went wrong

      # alway allow selfupdate
      if [[ "$1" != "selfupdate" ]]
      then
         if [[ -d "${CHROOT}" ]]
         then
            umountChrootFS

            # does not abort if uninstall
            if [[ "$1" != "uninstall" ]]
            then
               die "Something went wrong. Correct or to reinstall, run: ./${SCRIPTNAME} uninstall ; ./${SCRIPTNAME} -i"
            fi

         else
            echo "To install the chrooted Checkpoint client software, run:" >&2

            # appropriate install command
            # wether vpn.conf is present
            if [[ -f "${CONFFILE}" ]]
            then
               die  "./${SCRIPTNAME} -i"
            else
               die  "./${SCRIPTNAME} -i --vpn FQDN"
            fi
         fi
      fi
   fi
}

      
# arguments - command handling
argCommands()
{
   PreCheck2 "$1"

   case "$1" in

      start)        doStart ;; 
      restart)      doStart ;;
      stop)         doStop ;;
      disconnect)   doDisconnect ;;
      fixdns)       fixDNS2 ;;
      split)        Split ;;
      status)       showStatus ;;
      shell)        doShell ;;
      uninstall)    doUninstall ;;
      upgrade)      Upgrade ;;
      selfupdate)   selfUpdate ;;
      *)            do_help ;;         # default 

   esac

}

#
# chroot setup/install section(1st time running script)
#

# minimal checks before install
preFlight()
{
   # if not sudo/root, call the script as root/sudo script
   if [[ "${EUID}" -ne 0 ]] || [[ "${install}" -eq false ]]
   then
      exec sudo "$0" "${args[@]}"
   fi

   if  isCShellRunning 
   then
      die "CShell running. Before proceeding, run: ./${SCRIPTNAME} uninstall" 
   fi

   if [[ -d "${CHROOT}" ]]
   then
      # just in case, for manual operations
      umountChrootFS

      die "${CHROOT} present. Before install, run: ./${SCRIPTNAME} uninstall" 
   fi
}


# CentOS 8 changed to upstream distribution
# CentOS Stream beta without epel repository
# make necessary changes to stock images
needCentOSFix()
{
   # CentOS 8 no more
   if grep "^CentOS Linux release 8" /etc/redhat-release &> /dev/null
   then
      # change reposs to CentOS Stream 8
      sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
      sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

      # we came here because we failed to install epel-release, so trying again
      dnf -y install epel-release || die "could not install epel-release"
   else
      # fix for older CentOS Stream 9 VMs (osboxes)
      if  grep "^CentOS Stream release" /etc/redhat-release &> /dev/null
      then
         # update repositories (and keys)
         dnf -y install centos-stream-repos

         # try to install epel-release again
         dnf -y install epel-release || die "could not install epel-release. Fix it"
      else
         die "could not install epel-release"
      fi
   fi
}


# get, compile and install Slackware SlackBuild packages
GetCompileSlack()
{
   local SLACKBUILDREPOBASE
   local SLACKVERSION
   local SLACKBUILDREPO
   local DIR
   local pkg
   local BUILD
   local NAME
   local INFO
   local DOWNLOAD

   # Build SlackBuild repository base string
   SLACKBUILDREPOBASE="https://slackbuilds.org/slackbuilds/"
   # version in current can be 15.0+
   SLACKVERSION=$(awk -F" " ' { print $2 } ' /etc/slackware-version | tr -d "+" )
   # SlackBuilds is organized per version
   SLACKBUILDREPO="${SLACKBUILDREPOBASE}/${SLACKVERSION}/"

   # delete packages from /tmp
   rm -f /tmp/*tgz
 
   # save current directory
   pushd .

   # create temporary directory for downloading SlackBuilds
   DIR=$(mktemp -d -p . )
   mkdir -p "${DIR}" || die "could not create ${DIR}"
   cd "${DIR}" || die "could not enter ${DIR}"

   # cycle packages we want to fetch, compile and install
   for pkg in "development/dpkg" "system/debootstrap" "system/jq"
   do
      # last part of name from $pkg
      NAME=${pkg##*/}

      # if already installed no need to compile again
      # debootstrap version in SlackWare too old to be useful
      if [[ ${NAME} != "debootstrap" ]]
      then
         which ${NAME} || continue 
      fi

      # save current directory/cwd
      pushd .
     
      # get SlackBuild package 
      BUILD="${SLACKBUILDREPO}${pkg}.tar.gz"
      wget "${BUILD}" || die "could not download ${BUILD}"

      # extract it and enter directory
      tar -zxvf ${NAME}.tar.gz
      cd "$NAME" || die "cannot cd ${NAME}"

      # if debootstrap package
      if [[ "${NAME}" == "debootstrap" ]]
      then
         # debootstrap version is too old in SlackBuild rules
         # replace with a far newer version
         DOWNLOAD="http://deb.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.123.tar.gz"

         # changing version for SBo.tgz too reflect that
         sed -i 's/^VERSION=.*/VERSION=${VERSION:-1.0.123}/' ./${NAME}.SlackBuild

         # the Debian tar.gz only creates a directory by name
         # contrary to the Ubuntu source repository 
         # where debootstrap.SlackBuild is fetching the older source version
         sed -i 's/cd $PRGNAM-$VERSION/cd $PRGNAM/' ./${NAME}.SlackBuild
      else
         # get info file frrom SlackBuild package
         INFO="${SLACKBUILDREPO}${pkg}/${NAME}.info"
         wget "${INFO}" || die "could not download ${INFO}"

         # get URL from downloading corresponding package source code
         DOWNLOAD=$(awk -F= ' /DOWNLOAD/ { gsub("\"", ""); print $2 } ' "${NAME}.info")
      fi

      # Download package source code
      wget "${DOWNLOAD}" || die "could not download ${DOWNLOAD}"

      # execute SlackBuild script for patching, compiling, 
      # and generating SBo.tgz instalation package
      ./${NAME}.SlackBuild
     
      # return saved directory at the loop beggining
      popd || die "error restoring cwd [for]"
   done
 
   # return to former saved directory
   popd || die "error restoring cwd"

   # and delete temporary directory
   rm -rf "${DIR}"

   # install SBo.tgz just compiled/created packages
   installpkg /tmp/*tgz

   # delete packages
   rm -f /tmp/*tgz
}


# debootstrap hack
# if not present and having dpkg
# we can "force install it"
# debootstap just a set of scripts and configuration files
InstallDebootstrapDeb()
{
   if which dpkg && ! which debootstrap
   then
      FILE="http://deb.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.123_all.deb"
      wget "${FILE}" || die "could not download ${FILE}"
      dpkg -i --force-all debootstrap_1.0.123_all.deb
      rm -f debootstrap_1.0.123_all.deb
   fi
}

# installs package requirements
installPackages()
{
   local VERSION
   local FILE

   # if Debian family based
   if [[ "${DEB}" -eq 1 ]]
   then
      # update metadata
      apt -y update

      #apt -y upgrade

      # install needed packages
      apt -y install ca-certificates x11-xserver-utils jq wget debootstrap
      # we want to make sure resolconf is the last one
      [[ ${DEEPIN} -eq 0 ]] && apt -y install resolvconf
      # clean APT host cache
      apt clean
   fi

   # if RedHat family based
   if [[ "${RH}" -eq 1 ]]
   then
      #dnf makecache

      # attempts to a poor's man detection of not needing to setup EPEL
      dnf -y install debootstrap

      if ! which debootstrap
      then
         # epel-release not needed for Fedora and Mageia
         if egrep -vi "^Fedora|^Mageia|Mandriva" /etc/redhat-release &> /dev/null
         then
            # if not RedHat
            if grep -E "^REDHAT_SUPPORT_PRODUCT_VERSION|^ORACLE_SUPPORT_PRODUCT_VERSION" /etc/os-release &> /dev/null  
            then
               # if RedHat
               VERSION=$(awk -F= ' /_SUPPORT_PRODUCT_VERSION/ { gsub("\"", ""); print $2 } ' /etc/os-release | cut -f1 -d. )
               dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${VERSION}.noarch.rpm"
            else
               dnf -y install epel-release || needCentOSFix
            fi
         else
            if grep "^Mageia" /etc/redhat-release &> /dev/null
            then
               dnf -y install NetworkManager 
            fi
         fi
      fi

      dnf -y install ca-certificates jq wget debootstrap

      # not installed in all variants as a debootstrap dependency
      if ! dnf -y install dpkg 
      then
         grep "OpenMandriva Lx release 4.3" /etc/redhat-release &> /dev/null && dnf -y install http://abf-downloads.openmandriva.org/4.3/repository/x86_64/unsupported/release/dpkg-1.21.1-1-omv4050.x86_64.rpm http://abf-downloads.openmandriva.org/4.3/repository/x86_64/unsupported/release/perl-Dpkg-1.21.1-1-omv4050.noarch.rpm
      fi
      

      # xhost should be present
      if [[ ! -f "/usr/bin/xhost" ]]
      then
         dnf -y install xorg-x11-server-utils
         dnf -y install xhost
      fi
      dnf clean all 
   fi

   # if Arch Linux
   if [[ "${ARCH}" -eq 1 ]]
   then
      # Arch is a rolling distro, should we have an update here?
      
      # install packages
      pacman --needed -Syu ca-certificates xorg-xhost jq wget debootstrap
      pacman -S openresolv
   fi

   # if SUSE based
   if [[ "${SUSE}" -eq 1 ]]
   then
      zypper ref

      zypper -n install ca-certificates jq wget dpkg xhost dnsmasq

      which dpkg || die "could not install software"

      # will fail in SLES
      zypper -n install debootstrap

      zypper clean

      # SLES does have dpkg, but not debootstrap in repositories
      # debootstrap is just a set of scripts and files
      # install deb file from debian pool
      InstallDebootstrapDeb
   fi

   # if Void based
   if [[ "${VOID}" -eq 1 ]]
   then
      # Void is a rolling distro
      # update
      xbps-install -yu xbps
      xbps-install -ySu

      # needed packages
      # some of them already installed
      xbps-install -yS void-repo-nonfree void-repo-multilib-nonfree
      xbps-install -yS ca-certificates xhost jq wget debootstrap dpkg openresolv
   fi

   # if Gentoo based
   if [[ "${GENTOO}" -eq 1 ]]
   then
      # install/update packages
      emerge --ask n ca-certificates xhost app-misc/jq debootstrap dpkg

      # Redcore Linux has the wrong URL, cant compile debootrap as of June 2022
      InstallDebootstrapDeb
   fi

   # if Slackware
   if [[ "${SLACKWARE}" -eq 1 ]]
   then
      GetCompileSlack
   fi
}

# fix DNS - Arch
fixARCHDNS()
{
   local counter

   # seems not to be needed
   # if ArchLinux and systemd-resolvd active
   #if [[ "${ARCH}" -eq 1 ]] && [[ -f "/run/systemd/resolve/stub-resolv.conf" ]]
   #then
   #
   #  # stop resolved and configure it to not be active on boot 
   #  systemctl stop  systemd-resolved
   #   systemctl disable systemd-resolved
   #   systemctl mask systemd-resolved 
   #fi
   if [[ "${ARCH}" -eq 1 ]] && [[ ! -f "/run/resolvconf/interfaces/NetworkManager" ]]
   then
      cat <<-'EOF17' > /etc/NetworkManager/conf.d/rc-manager.conf
	[main]
	rc-manager=resolvconf
	EOF17

      # replace /etc/resolv.conf for a resolved link
      cd /etc || die "was not able to cd /etc"

      ln -sf ../run/resolvconf/interfaces/NetworkManager resolv.conf

      # reload NeworkManager
      systemctl reload NetworkManager

      # wait for it to be up
      counter=0
      while ! systemctl is-active NetworkManager &> /dev/null
      do 
         sleep 4
         (( counter=counter+1 ))
         [[ "$counter" -eq 20 ]] && die "NetworkManager not going live"
      done
   fi
}

# fix DNS RH family if systemd-resolved not active
fixRHDNS()
{
   local counter

   # if RedHat and systemd-resolvd not active
   if [[ "${RH}" -eq 1 ]] && [[ ! -f "/run/systemd/resolve/stub-resolv.conf" ]]
   then

      # CentOS Stream 9 does not install systemd-resolved by default
      if [[ ! -f "/usr/lib/systemd/systemd-resolved" ]]
      then	    
         dnf -y install systemd-resolved 
      fi

      # start it and configure it to be active on boot 
      systemctl unmask systemd-resolved &> /dev/null
      systemctl start  systemd-resolved
      systemctl enable systemd-resolved

      # Possibly waiting for systemd service to be active
      counter=0
      while ! systemctl is-active systemd-resolved &> /dev/null
      do
         sleep 2
         (( counter=counter+1 ))
         [[ "$counter" -eq 30 ]] && die "systemd-resolved not going live"
      done

      [[ ! -f "/run/systemd/resolve/stub-resolv.conf" ]] && die "Something went wrong activating systemd-resolved"

      # if any old style interface scripts
      # we need them controlled by NetworkManager
      sed -i '/NMCONTROLLED/d' /etc/sysconfig/network-scripts/ifcfg-*  &>/dev/null
      sed -i '$ a NMCONTROLLED="yes"' /etc/sysconfig/network-scripts/ifcfg-*  &>/dev/null

      # replace /etc/resolv.conf for a resolved link 
      cd /etc || die "was not able to cd /etc"

      ln -sf ../run/systemd/resolve/stub-resolv.conf resolv.conf

      # reload NeworkManager
      systemctl reload NetworkManager

      # wait for it to be up
      counter=0
      while ! systemctl is-active NetworkManager &> /dev/null
      do 
         sleep 4
         (( counter=counter+1 ))
         [[ "$counter" -eq 20 ]] && die "NetworkManager not going live"
      done
   fi
}

# fix DNS - SUSE 
fixSUSEDNS()
{
   if [[ "${SUSE}" -eq 1 ]] && grep -v ^NETCONFIG_DNS_FORWARDER=\"dnsmasq\" /etc/sysconfig/network/config &> /dev/null
   then

      # replace DNS line
      #
      sed -i 's/^NETCONFIG_DNS_FORWARDER=.*/NETCONFIG_DNS_FORWARDER="dnsmasq"/g' /etc/sysconfig/network/config

      # replace /etc/resolv.conf for a resolved link
      cd /etc || die "was not able to cd /etc"

      ln -sf ../run/netconfig/resolv.conf resolv.conf

      # restart network
      systemctl restart network
   fi
}

# fix DNS - DEEPIN
fixDEEPINDNS()
{
   if [[ "${DEEPIN}" -eq 1 ]]
   then
      systemctl enable systemd-resolved.service

      # replace /etc/resolv.conf for a resolved link
      cd /etc || die "was not able to cd /etc"

      ln -sf ../run/systemd/resolve/stub-resolv.conf resolv.conf
   fi
}

# "bug/feature": check DNS health
checkDNS()
{
   # ask once for slow systems to fail/cache it
   getent ahostsv4 "${VPN}"  &> /dev/null
   
   # test, try to fix, test
   if ! getent ahostsv4 "${VPN}" &> /dev/null
   then
      # at least Parrot and Mint seem to need this
      fixDNS2

      # test it now to see if fixed
      if ! getent ahostsv4 "${VPN}" &> /dev/null
      then
         echo "DNS problems after installing resolvconf?" >&2
         echo "Not resolving ${VPN} DNS" >&2
         echo "Relaunch ${SCRIPTNAME} for possible timeout issues" >&2
         die "Otherwise fix or reboot to fix" 
      fi	   
   fi
}


# creating the Debian minbase (minimal) chroot
createChroot()
{
   echo "please wait..." >&2
   echo "slow command, often debootstrap hangs talking with Debian repositories" >&2
   echo "do ^C and start it over again if needed" >&2

   mkdir -p "${CHROOT}" || die "could not create directory ${CHROOT}"

   # create and populate minimal 32-bit Debian chroot
   if ! debootstrap --variant="${VARIANT}" --arch i386 "${RELEASE}" "${CHROOT}" "${DEBIANREPO}"
   then
      echo "chroot ${CHROOT} unsucessful creation" >&2
      die "run sudo rm -rf ${CHROOT} and do it again" 
   fi
}


# create user for running CShell
# to avoid running server as root
# more secure running as an independent user
createCshellUser()
{
   # create group 
   getent group "^${CSHELL_GROUP}:" &> /dev/null || groupadd --gid "${CSHELL_GID}" "${CSHELL_GROUP}" 2>/dev/null ||true

   # create user
   if ! getent passwd "^${CSHELL_USER}:" &> /dev/null 
   then
      useradd \
            --uid "${CSHELL_UID}" \
            --gid "${CSHELL_GID}" \
            --no-create-home \
            --home "${CSHELL_HOME}" \
            --shell "/bin/false" \
            "${CSHELL_USER}" 2>/dev/null || true
   fi
   # adjust file and directory permissions
   # create homedir 
   test -d "${CSHELL_HOME}" || mkdir -p "${CSHELL_HOME}"
   chown -R "${CSHELL_USER}":"${CSHELL_GROUP}" "${CSHELL_HOME}"
   chmod -R u=rwx,g=rwx,o= "$CSHELL_HOME"
}


# build required chroot file system structure + scripts
buildFS()
{
   cd "${CHROOT}" >&2 || die "could not chdir to ${CHROOT}" 

   # for sharing X11 with the host
   mkdir -p "tmp/.X11-unix"

   # for leaving cshell_install.sh happy
   mkdir -p "${CHROOT}/${CSHELL_HOME}/.config" || die "couldn not mkdir ${CHROOT}/${CSHELL_HOME}/.config"

   # for showing date right when in shell mode inside chroot
   echo "TZ=${TZ}; export TZ" >> root/.profile

   # getting the last version of the agents installation scripts
   # from the firewall
   rm -f snx_install.sh cshell_install.sh

   # download SNX installation scripts from CheckPoint machine
   if wget --no-check-certificate "https://${VPN}/SNX/INSTALL/snx_install.sh"
   then 
      # download CShell installation scripts from CheckPoint machine
      wget --no-check-certificate "https://${VPN}/SNX/INSTALL/cshell_install.sh" || die "could not download cshell_install.sh"
      # register CShell installed version for later
      wget -q -O- --no-check-certificate "https://${VPN}/SNX/CSHELL/cshell_ver.txt" 2> /dev/null > root/.cshell_ver.txt
   else
      # download SNX installation scripts from CheckPoint machine
      wget --no-check-certificate "https://${VPN}/${SSLVPN}/SNX/INSTALL/snx_install.sh" || die "could not download snx_install.sh"
      # download CShell installation scripts from CheckPoint machine
      wget --no-check-certificate "https://${VPN}/${SSLVPN}/SNX/INSTALL/cshell_install.sh" || die "could not download cshell_install.sh"
      # register CShell installed version for later
      wget -q -O- --no-check-certificate "https://${VPN}/${SSLVPN}/SNX/CSHELL/cshell_ver.txt" 2> /dev/null > root/.cshell_ver.txt
   fi

   mv cshell_install.sh "${CHROOT}/root"
   mv snx_install.sh "${CHROOT}/root"

   # snx calls modprobe, modprobe is not needed
   # create a fake one inside chroot returning success
   cat <<-EOF5 > sbin/modprobe
	#!/bin/bash
	exit 0
	EOF5

   # CShell abuses who in a bad way
   # garanteeing consistency
   mv usr/bin/who usr/bin/who.old
   cat <<-EOF6 > usr/bin/who
	#!/bin/bash
	echo -e "${CSHELL_USER}\t:0"
	EOF6

   # hosts inside chroot
   cat <<-EOF7 > etc/hosts
	127.0.0.1 localhost
	${VPNIP} ${VPN}
	EOF7

   # add host hostname to hosts 
   if [[ -n "${HOSTNAME}" ]]
   then
      # inside chroot
      echo -e "\n127.0.0.1 ${HOSTNAME}" >> etc/hosts

      # add hostname to host /etc/hosts
      if ! grep "${HOSTNAME}" /etc/hosts &> /dev/null
      then
         echo -e "\n127.0.0.1 ${HOSTNAME}" >> /etc/hosts
      fi
   fi

   # APT proxy for inside chroot
   if [[ -n "${CHROOTPROXY}" ]]
   then
      cat <<-EOF8 > etc/apt/apt.conf.d/02proxy
	Acquire::http::proxy "${CHROOTPROXY}";
	Acquire::ftp::proxy "${CHROOTPROXY}";
	Acquire::https::proxy "${CHROOTPROXY}";
	EOF8
   fi

   # Debian specific, file signals chroot to some scripts
   # including default root prompt
   echo "${CHROOT}" > etc/debian_chroot

   # if needing java8
   # --oldjava
   if [[ ${JAVA8} -eq true ]]
   then
      # old repository for getting JDK 8 and dependencies
      echo 'deb http://security.debian.org/ stretch/updates main' > etc/apt/sources.list.d/stretch.list
   fi

   # script for finishing chroot setup already inside chroot
   cat <<-EOF9 > root/chroot_setup.sh
	#!/bin/bash
	# "booleans"
	true=0
	false=1
	# --oldjava
        JAVA8=${JAVA8}

	# create cShell user
	# create group 
	addgroup --quiet --gid "${CSHELL_GID}" "${CSHELL_GROUP}" 2>/dev/null ||true
	# create user
	adduser --quiet \
	        --uid "${CSHELL_UID}" \
	        --gid "${CSHELL_GID}" \
	        --no-create-home \
	        --disabled-password \
	        --home "${CSHELL_HOME}" \
	        --gecos "Checkpoint Agent" \
	        "${CSHELL_USER}" 2>/dev/null || true

	# adjust file and directory permissions
	# create homedir 
	test  -d "${CSHELL_HOME}" || mkdir -p "${CSHELL_HOME}"
	chown -R "${CSHELL_USER}":"${CSHELL_GROUP}" "${CSHELL_HOME}"
	chmod -R u=rwx,g=rwx,o= "$CSHELL_HOME"

	# create a who apt diversion for the fake one not being replaced
	# by security updates inside chroot
	dpkg-divert --divert /usr/bin/who.old --no-rename /usr/bin/who

	# needed packages
	apt -y install libstdc++5 libx11-6 libpam0g libnss3-tools procps net-tools bzip2

        # --oldjava
	if [[ ${JAVA8} -eq true ]]
	then
	   # needed package
           # update to get metadata of stretch update repository
           # so we can get OpenJDK 8+dependencies
           # update intentionally done only after installing other packages
	   apt -y update
	   apt -y install openjdk-8-jdk 
	else
	   # needed package
	   apt -y install openjdk-11-jre
	fi

	# clean APT chroot cache
	apt clean
	
	# install SNX and CShell
	/root/snx_install.sh
	echo "Installing CShell" >&2
	DISPLAY="${DISPLAY}" PATH=/nopatch:"${PATH}" /root/cshell_install.sh 
	
	exit 0
	EOF9

        # directory with stub commands for cshell_install.sh
        mkdir nopatch

	# fake certutil
	# we are not dealing either with browsers or certificates inside chroot
	# 
        # -H returns 1 (test installed)
	# otherwise 0
	cat <<-'EOF18' > nopatch/certutil
	#!/bin/bash
	if [[ "$1" == "-H" ]]
	then
	   exit 1
	else
	   exit 0
	fi
	EOF18

   # fake xterm and xhost 
   # since they are not needed inside chroot
   # both return 0
   ln -s ../sbin/modprobe nopatch/xhost
   ln -s ../sbin/modprobe nopatch/xterm

   # fake barebones Mozilla/Firefox profile
   # just enough to make cshell_install.sh happy
   mkdir -p "home/${CSHELL_USER}/.mozilla/firefox/3ui8lv6m.default-release"
   touch "home/${CSHELL_USER}/.mozilla/firefox/3ui8lv6m.default-release/cert9.db"
   cat <<-'EOF16' > "home/${CSHELL_USER}/.mozilla/firefox/installs.ini"
	Path=3ui8lv6m.default-release
	Default=3ui8lv6m.default-release
	EOF16

   # creates a subshell
   # to avoid possible cwd complications
   # in the case of an error
   ( 
   # add profiles.ini to keep variations of cshell_install.sh happy
   cd "home/${CSHELL_USER}/.mozilla/firefox/" || die "was not able to cd home/${CSHELL_USER}/.mozilla/firefox/"
   ln -s installs.ini profiles.ini
   )

   chmod a+rx usr/bin/who sbin/modprobe root/chroot_setup.sh root/snx_install.sh root/cshell_install.sh nopatch/certutil
}


# create chroot fstab for sharing kernel 
# internals and directories/files with the host
FstabMount()
{
   # fstab for building chroot
   # run nscd mount is for *not* sharing nscd between host and chroot
   cat <<-EOF10 > etc/fstab
	/tmp            ${CHROOT}/tmp           none bind 0 0
	/dev            ${CHROOT}/dev           none bind 0 0
	/dev/pts        ${CHROOT}/dev/pts       none bind 0 0
	/sys            ${CHROOT}/sys           none bind 0 0
	/var/log        ${CHROOT}/var/log       none bind 0 0
	/run            ${CHROOT}/run           none bind 0 0
	/proc           ${CHROOT}/proc          proc defaults 0 0
	/dev/shm        ${CHROOT}/dev/shm       none bind 0 0
	/tmp/.X11-unix  ${CHROOT}/tmp/.X11-unix none bind 0 0
	EOF10

   #mount --fstab etc/fstab -a
   mountChrootFS
}


# try to create xdg autorun file similar to CShell
# but for all users instead of one user private profile
# on the host system
XDGAutoRun()
{
   # directory for starting apps upon X11 login
   # /etc/xdg/autostart/
   if [[ -d "$(dirname ${XDGAUTO})" ]]
   then
      # XDGAUTO="/etc/xdg/autostart/cshell.desktop"
      cat > "${XDGAUTO}" <<-EOF11
	[Desktop Entry]
	Type=Application
	Name=cshell
	Exec=sudo "${INSTALLSCRIPT}" -s -c "${CHROOT}" start
	Icon=
	Comment=
	X-GNOME-Autostart-enabled=true
	X-KDE-autostart-after=panel
	X-KDE-StartupNotify=false
	StartupNotify=false
	EOF11
      
      # message advising to add sudo without password
      # if you dont agent wont be started automatically after login
      # and vpn.sh start will be have to be done after each X11 login
      echo "Added graphical auto-start" >&2
      echo

      echo "For it to run, modify your /etc/sudoers for not asking for password" >&2
      echo "As in:" >&2
      echo >&2
      echo "%sudo	ALL=(ALL:ALL) NOPASSWD:ALL" >&2
      echo "#or: " >&2
      echo "%sudo	ALL=(ALL:ALL) NOPASSWD: ${INSTALLSCRIPT}" >&2

      # if sudo, SUDO_USER identifies the non-privileged user 
      if [[ -n "${SUDO_USER}" ]]
      then
         echo "#or: " >&2
         echo "${SUDO_USER}	ALL=(ALL:ALL) NOPASSWD:ALL" >&2
         echo "#or: " >&2
         echo "${SUDO_USER}	ALL=(ALL:ALL) NOPASSWD: ${INSTALLSCRIPT}" >&2
      fi
      echo >&2

      # add entry for it to be executed
      # upon graphical login
      # so it does not need to be started manually
      if ! grep "${INSTALLSCRIPT}" /etc/sudoers &>/dev/null
      then
         echo
         echo -e "\n%sudo       ALL=(ALL:ALL) NOPASSWD: ${INSTALLSCRIPT}" >> /etc/sudoers
         echo "%sudo       ALL=(ALL:ALL) NOPASSWD: ${INSTALLSCRIPT}" >&2
         echo "added to /etc/sudoers" >&2
      fi

   else
      echo "Was not able to create XDG autorun desktop entry for CShell" >&2
   fi
}


# create /opt/etc/vpn.conf
# upon service is running first time successfully
createConfFile()
{
    # create /opt/etc if not there
    mkdir -p "$(dirname ${CONFFILE})" 2> /dev/null

    # save VPN, VPNIP
    cat <<-EOF13 > "${CONFFILE}"
	VPN="${VPN}"
	VPNIP="${VPNIP}"
	SPLIT="${SPLIT}"
	EOF13

    # if not default, save it
    [[ "${SSLVPN}" != "sslvpn" ]] && echo "SSLVPN=\"${SSLVPN}\"" >> "${CONFFILE}"
}


# last leg inside/building chroot
#
# minimal house keeping and user messages
# after finishing chroot setup
chrootEnd()
{
   local ROOTHOME

   # do the last leg of setup inside chroot
   doChroot /bin/bash --login -pf <<-EOF15
	/root/chroot_setup.sh
	EOF15

   # if sucessful installation
   if isCShellRunning && [[ -f "${CHROOT}/usr/bin/snx" ]]
   then
      # delete temporary setup scripts from chroot's root home
      ROOTHOME="${CHROOT}/root"
      rm -f "${ROOTHOME}/chroot_setup.sh" "${ROOTHOME}/cshell_install.sh" "${ROOTHOME}/snx_install.sh" 

      # copy this script to /usr/local/bin
      cp "${SCRIPT}" "${INSTALLSCRIPT}"
      chmod a+rx "${INSTALLSCRIPT}"

      # create /etc/vpn.conf
      createConfFile

      # install xdg autorun file
      # last thing to run
      XDGAutoRun

      echo "chroot setup done." >&2
      echo "${SCRIPT} copied to ${INSTALLSCRIPT}" >&2
      echo >&2

      # install Policy for CShell localhost certificate
      FirefoxPolicy install

      # if localhost generated certificate not accepted, VPN auth will fail
      # and will ask to "install" software upon failure
      echo "open browser with https://localhost:14186/id to accept new localhost certificate" >&2
      echo
      echo "afterwards open browser at https://${VPN} to login into VPN" >&2
      echo "If it does not work, launch ${SCRIPTNAME} in a terminal from the X11 console" >&2
      echo
      echo "doing first restart" >&2
      doStart
   else
      # unsuccessful setup
      umountChrootFS

      die "Something went wrong. Chroot unmounted. Fix it or delete $CHROOT and run this script again" 

   fi
}


# main chroot install routine
InstallChroot()
{
   preFlight
   installPackages
   fixRHDNS
   fixARCHDNS
   fixSUSEDNS
   fixDEEPINDNS
   checkDNS
   createChroot
   createCshellUser
   buildFS
   FstabMount
   fixDNS
   chrootEnd
}


# main ()
main()
{
   # command options handling
   doGetOpts "$@"

   # clean all the getopts logic from the arguments
   # leaving only commands
   shift $((OPTIND-1))

   # after options check, as we want help to work.
   PreCheck "$1"

   if [[ "${install}" -eq false ]]
   then

      # handling of stop/start/status/shell 
      argCommands "$1"
   else
      # -i|--install subroutine
      InstallChroot
   fi

   exit 0
}


# main stub will full arguments passing
main "$@"

