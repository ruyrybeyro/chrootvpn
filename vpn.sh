#!/bin/bash 
#
# Rui Ribeiro
#
# VPN client chroot'ed setup/wrapper for Debian/Ubuntu/RH/CentOS/Fedora hosts 
# Checkpoint R80.10 and up
#
# Please fill VPN and VPNIP before using this script.
# SPLIT might or not have to be filled, depending on your needs 
# and Checkpoint VPN routes.
#
# if /opt/etc/vpn.conf is present the above script settings will be 
# ignored. vpn.conf is created upon first instalation.
#
# first time run it as ./vpn.sh -i
# Accept localhost certificate visiting https://localhost:14186/id
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
# hosts: 
#        Debian 10 
#        Debian 11 
#        Ubuntu LTS 18.04 
#        Ubuntu LTS 22.04 
#        Mint   20.2
#        antiX-21
#        Fedora 23 
#        Fedora 36
#        Rocky  8.6
#        CentOS 8 Stream
#        CentOS 9 Stream
#        AlmaLinux release 9.0
#
# For DNS sync between host and chroot
# "Debian" hosts resolvconf and /run/resolvconf/resolv.conf
# "RedHat" hosts systemd-resolved and /run/systemd/resolve/stub-resolv.conf
#

# script/deploy version, make the same as deploy
VERSION="v0.997"

# default chroot location (700 MB needed - 1.5GB while installing)
CHROOT="/opt/chroot"

# default configuration file
# created first time upon successful setup/run
# so vpn.sh can be successfuly replaced by new versions
# or reinstalled from scratch
CONFFILE="/opt/etc/vpn.conf"

[ -f "${CONFFILE}" ] && . "${CONFFILE}"

# Sane defaults:
 
# Checkpoint VPN address
# selfupdate brings them from the older version
# Fill VPN *and* VPNIP *before* using the script
# if filling in keep the format
# values used first time installing, 
# otherwise /opt/etc/vpn.conf overrides them
[ -z "$VPN" ] && VPN=""
[ -z "$VPNIP" ] && VPNIP=""

# split VPN routing table if deleting VPN gateway is not enough
# selfupdate brings it from the older version
# if empty script will delete VPN gateway
# if filling in keep the format
# value used first time installing, 
# otherwise /opt/etc/vpn.conf overrides it
[ -z "$SPLIT" ] && SPLIT=""

# we test / and sslvnp SSL VPN portal PATHs.
# Change here for a custom PATH
[ -z "$SSLVPN" ] && SSLVPN="sslvpn"

# OS to deploy inside 32-bit chroot  
VARIANT="minbase"
RELEASE="bullseye" # Debian 11
DEBIANREPO="http://deb.debian.org/debian/" # fastly repo

# github repository for command selfupdate
GITHUB_REPO="ruyrybeyro/chrootvpn"

# used during initial chroot setup
# for chroot shell correct time
[ -z "${TZ}" ] && TZ='Europe/Lisbon'

# URL for testing if split or full VPN
URL_VPN_TEST="https://www.debian.org"

# CShell writes on the X11 display
[ -z "${DISPLAY}" ] && export DISPLAY=":0.0"

# dont bother with locales
export LC_ALL=C LANG=C

# script full PATH
SCRIPT=$(realpath "${BASH_SOURCE[0]}")

# script name
SCRIPTNAME=$(basename "${SCRIPT}")

#  preserve program passed arguments $@ into a BASH array
args=("$@")

# VPN interface
TUNSNX="tunsnx"

# GNOME autostart X11 file
XDGAUTO="/etc/xdg/autostart/cshell.desktop"

# script PATH upon successful setup
INSTALLSCRIPT="/usr/local/bin/${SCRIPTNAME}"

# cshell user
CSHELL_USER=cshell
CSHELL_UID=9000
CSHELL_GROUP=${CSHELL_USER}
CSHELL_GID=9000
CSHELL_HOME="/home/${CSHELL_USER}"

# "booleans"
true=0
false=1

# PATH for being called outside the command line (from xdg)
PATH="/usr/bin:/usr/sbin:/bin/sbin:${PATH}"

#
# user interface handling
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
	--vpn        select another VPN DNS full name
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
   VPNIP=$(getent ahostsv4 "${VPN}" | awk 'NR==1 { print $1 } ' )
   [[ -z ${VPNIP} ]] && die "could not resolve ${VPN} DNS name"
}


# optional arguments handling
needs_arg() 
{ 
   [ -z "${OPTARG}" ] && die "No arg for --$OPT option"
}


# Redirect Output
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

      # long option: reformulate OPT and OPTARG
      if [ "${OPT}" = "-" ] 
      then   
         OPT=${OPTARG%%=*}       # extract long option name
         OPTARG=${OPTARG#"$OPT"}   # extract long option argument (may be empty)
         OPTARG=${OPTARG#=}      # if long option argument, remove assigning `=`
      fi

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
         ? )               exit 2;                   # bad short option (reported by getopts) 
       esac

   done
}


# minimal requirements check
PreCheck()
{
   # If not Intel based
   if [[ $(uname -m) != 'x86_64' ]] && [[ $(uname -m) != 'i386' ]]
   then
      die "This script is for Debian/Ubuntu Linux Intel based flavours only"
   fi

   # If not Debian/Ubuntu based
   if [ ! -f "/etc/debian_version" ] && [ ! -f "/etc/redhat-release" ] 
   then
      die "This script is only for Debian/Ubuntu or RedHat/CentOS Linux based flavours only" 
   else
      DEB=0
      RH=0

      if [ -f "/etc/debian_version" ]
      then
         DEB=1
         ischroot && die "Do not run this script inside a chroot"
      fi

      if [ -f "/etc/redhat-release" ]
      then
         RH=1
      fi

      if [[ ${DEB} -eq 0 ]] && [[ ${RH} -eq 0 ]]
      then
         die "Only Debian and RedHat family distributions supported"
      fi
   fi

   if [[ -z "${VPN}" ]] || [[ -z "${VPNIP}" ]] 
   then
      [[ "$1" == "uninstall" ]] || die "Run vpn.sh -i --vpn=FQDN or fill in VPN and VPNIP with the DNS FQDN and the IP address of your Checkpoint VPN server"
   fi

   # for using/relaunching
   # call the script with sudo
   [[ "${EUID}" -ne 0 ]] && exec sudo "$0" "${args[@]}" 
}


# wrapper for chroot
doChroot()
{
   # setarch i386 lies to uname about being 32 bits
   setarch i386 chroot "${CHROOT}" "$@"
}


# C/Unix convention - 0 success, 1 failed
isCShellRunning()
{
   pgrep -f CShell &>/dev/null
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
      if [ $? -eq 1 ]
      then
         # consistency checks
         if [[ ! -f "${CHROOT}/etc/fstab" ]]
         then
            die "no ${CHROOT}/etc/fstab" 
         fi

         # mount using fstab inside chroot, all filesystems
         mount --fstab "${CHROOT}/etc/fstab" -a
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
      [ -f "${CHROOT}/etc/fstab" ] && doChroot /usr/bin/umount -a 2> /dev/null
         
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


#
# Client wrapper section
#

# split command
Split()
{
   # split tunnel, only after VPN is up

   # if SPLIT empty
   if [[ -z "${SPLIT+x}" ]]
   then
      echo "If this does not work, please fill in SPLIT with a network/mask list eg x.x.x.x/x x.x.x.x/x" >&2
      echo "either in ${CONFFILE} or in ${SCRIPT}"
      ip route delete 0.0.0.0/1
      echo "default VPN gateway deleted" >&2
   else 
      # get local VPN given IP address
      IP=$(ip -4 addr show "${TUNSNX}" | awk '/inet/ { print $2 } ')

      # clean all VPN routes
      ip route flush table main dev "${TUNSNX}"

      # create new VPN routes according to $SPLIT
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
   #uname -m
   echo -n "$(arch) "
   uname -r
   echo -n "Chroot: "

   doChroot /bin/bash --login -pf <<-EOF2 | awk -v ORS= -F"=" '/^PRETTY_NAME/ { gsub("\"","");print $2" " } '
	cat /etc/os-release
	EOF2

   # print--architecture and not uname because chroot shares the same kernel
   doChroot /bin/bash --login -pf <<-EOF3
	/usr/bin/dpkg --print-architecture
	EOF3

   # SNX
   echo
   echo -n "SNX - installed              "
   doChroot snx -v 2> /dev/null | awk '/build/ { print $2 }'
   echo -n "SNX - available for download "

   if ! wget -q -O- --no-check-certificate "https://${VPN}/SNX/CSHELL/snx_ver.txt" 2> /dev/null
   then
      wget -q -O- --no-check-certificate "https://${VPN}/${SSLVPN}/SNX/CSHELL/snx_ver.txt" 2> /dev/null || echo "Could not get SNX download version" >&2
   fi

   # IP connectivity
   echo
   # IP address VPN local address given
   IP=""
   IP=$(ip -4 addr show "${TUNSNX}" 2> /dev/null | awk '/inet/ { print $2 } ')

   echo -n "Linux  IP address: "
   hostname -I | awk '{print $1}'
   echo

   # if $IP not empty
   if [[ -n ${IP} ]]
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
   echo

   # VPN signature(s) - local - outside chroot
   echo "VPN signatures"
   bash -c 'cat /etc/snx/*.db' 2> /dev/null  # workaround for using * expansion inside sudo

   # DNS
   echo
   #resolvectl status
   cat /etc/resolv.conf
   echo
    
   # get latest release version
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

   # Debian family - resolvconf
   if [[ ${DEB} -eq 1 ]]
   then
      rm -f "${CHROOT}/etc/resolv.conf"
      ln -s ../run/resolvconf/resolv.conf "${CHROOT}/etc/resolv.conf"
   fi

   # RH family - systemd-resolved
   if [[ ${RH} -eq 1 ]]
   then
      rm -f "${CHROOT}/etc/resolv.conf"
      ln -s ../run/systemd/resolve/stub-resolv.conf "${CHROOT}/etc/resolv.conf"
   fi

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


fixDNS2()
{
   # try to restore resolv.conf
   if [[ ${DEB} -eq 1 ]]
   then
      resolvconf -u
   fi
   if [[ ${RH} -eq 1 ]]
   then
      authselect apply-changes
   fi
}


# disconnect SNX/VPN session
doDisconnect()
{
   # if snx/VPN up, disconnect
   pgrep snx > /dev/null && doChroot /usr/bin/snx -d

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

   # delete autorun file, chroot subdirectory and installed script
   rm -f  "${XDGAUTO}"          &>/dev/null
   rm -rf "${CHROOT}"           &>/dev/null
   rm -f  "${INSTALLSCRIPT}"    &>/dev/null
   userdel -rf "${CSHELL_USER}" &>/dev/null
   groupdel "${CSHELL_GROUP}"   &>/dev/null

   for DIR in "/usr/lib/firefox" "/usr/lib64/firefox" "/usr/lib/firefox-esr" "/usr/lib64/firefox-esr"
   do
      # delete Firefox policy for accepting localhost CShell certificate
      if grep CShell_Certificate "${DIR}/distribution/policies.json" &> /dev/null
      then
         rm -f "${DIR}/distribution/policies.json"
      fi
   done

   if [[ -f "${CONFFILE}" ]]
   then
      echo "${CONFFILE} not deleted. If you are not reinstalling do:"
      echo "sudo rm -f ${CONFFILE}"
      echo
      echo "cat ${CONFFILE}"
      cat ${CONFFILE}
      echo
   fi

   echo "chroot+checkpoint software deleted" >&2
}


# upgrade OS inside chroot
Upgrade() {
   doChroot /bin/bash --login -pf <<-EOF12
	apt update
	apt -y upgrade
        apt -y autoremove
	apt clean
	EOF12
}


# self update this script
selfUpdate() 
{
    # temporary file for downloading new vpn.sh    
    local vpnsh

    # get latest release version
    VER=$(wget -q -O- --no-check-certificate "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | jq -r ".tag_name")
    echo "current version     : ${VERSION}"

    [[ "${VER}" == "null" ]] || [[ -z "${VER}" ]] && die "did not find any github release. Something went wrong"

    if [[ "${VER}" > "${VERSION}" ]]
    then
        echo "Found a new version of ${SCRIPTNAME}, updating myself..."

        vpnsh=$(mktemp) || die "failed creating mktemp file"

        if wget -O "${vpnsh}" -o /dev/null "https://github.com/${GITHUB_REPO}/releases/download/${VER}/vpn.sh" 
        then

           # if script not run for /usr/local/bin, also update it
           [ "${INSTALLSCRIPT}" != "${SCRIPT}"  ] && cp -f "${vpnsh}" "${SCRIPT}"

           # update the onne in /usr/local/bin
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
            echo "./${SCRIPTNAME} -i" >&2
            echo "or" >&2

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
      selfupdate)   selfUpdate;;
      *)            do_help ;;

   esac

}

#
# chroot setup/install section(1st time running script)
#

# minimal checks before install
preFlight()
{
   # if not sudo/root, call the script as root/sudo script
   if [[ "${EUID}" -ne 0 ]] || [[ ${install} -eq false ]]
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


# CentOS 8 changed to upstream
# make necessary changes to stock image
needCentOSFix()
{
   if grep "^CentOS Linux release 8" /etc/redhat-release &> /dev/null
   then
      sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
      sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
       # we came here because we failed to install epel-release, so trying again
       yum -y install epel-release || die "could not install epel-release"
   else
      die "could not do yum. Fix it"
   fi
}


# system update and package requirements
installPackages()
{
   if [[ ${DEB} -eq 1 ]]
   then
      apt -y update
      #apt -y upgrade

      # install needed packages
      apt -y install debootstrap ca-certificates x11-xserver-utils jq wget
      # we want to make sure resolconf is the last one
      apt -y install resolvconf
      # clean APT host cache
      apt clean
   fi

   if [[ ${RH} -eq 1 ]]
   then
      # yum -y update

      # epel-release not needed for Fedora
      if grep -v ^Fedora /etc/redhat-release &> /dev/null
      then
         yum -y install epel-release || needCentOSFix
      fi

      yum -y install debootstrap ca-certificates jq wget 
      if [[ ! -f "/usr/bin/xhost" ]]
      then
         yum -y xorg-x11-server-utils
         yum -y xhost
      fi
      yum clean all 
   fi
}


# fix DNS RH family if systemd-resolved not active
fixRHDNS()
{
   local counter

   if [[ ${RH} -eq 1 ]] && [[ ! -f "/run/systemd/resolve/stub-resolv.conf" ]]
   then

      # CentOS 9 does not install systemd-resolved by default
      if [[ ! -f /usr/lib/systemd/systemd-resolved ]]
      then	    
         yum -y install systemd-resolved 
      fi

      # start it and configure it to be active on boot 
      systemctl unmask systemd-resolved &> /dev/null
      systemctl start  systemd-resolved
      systemctl enable systemd-resolved

      # Possibly waiting for sysstemd service to be active
      counter=0
      while ! systemctl is-active systemd-resolved &> /dev/null
      do
         sleep 2
         (( counter=counter+1 ))
         [[ $counter -eq 30 ]] && die "systemd-resolved not going live"
      done

      if [ ! -f /run/systemd/resolve/stub-resolv.conf ]
      then
         die "Something went wrong activating systemd-resolved"
      fi

      # if any old style interface scripts
      # we need them controlled by NetworkManager
      sed -i '/NMCONTROLLED/d' /etc/sysconfig/network-scripts/ifcfg-*  &>/dev/null
      sed -i '$ a NMCONTROLLED="yes"' /etc/sysconfig/network-scripts/ifcfg-*  &>/dev/null

      # replace /etc/resolv.conf for a resolved link 
      cd /etc || die "was not able to cd /etc"
      rm -f /etc/resolv.conf
      ln -s ../run/systemd/resolve/stub-resolv.conf resolv.conf

      # reload NeworkManager
      systemctl reload NetworkManager

      # wait for it to be up
      counter=0
      while ! systemctl is-active NetworkManager &> /dev/null
      do 
         sleep 4
         (( counter=counter+1 ))
         [[ $counter -eq 20 ]] && die "NetworkManager not going live"
      done
   fi
}


# "bug/feature": check DNS health
checkDNS()
{
   # ask once for slow systems to fail/cache it
   getent ahostsv4 "${VPN}"  &> /dev/null
   # test it now
   if ! getent ahostsv4 "${VPN}" &> /dev/null
   then
      echo "DNS problems after installing resolvconf?" >&2
      echo "Not resolving ${VPN} DNS" >&2
      echo "Relaunch ${SCRIPTNAME} for possible timeout issues" >&2
      die "Otherwise fix or reboot to fix" 
   fi	   
}


# creating the Debian minbase chroot
createChroot()
{
   echo "please wait..." >&2
   echo "slow command, often debootstrap hangs talking with Debian repositories" >&2
   echo "do ^C and start it over again if needed" >&2

   mkdir -p "${CHROOT}" || die "could not create directory ${CHROOT}"

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
   if ! getent group | grep -q "^${CSHELL_GROUP}:" 
   then
      addgroup --quiet --gid ${CSHELL_GID} ${CSHELL_GROUP} 2>/dev/null ||true
   fi
   # create user
   if ! getent passwd | grep -q "^${CSHELL_USER}:" 
   then
      adduser --quiet \
            --uid ${CSHELL_UID} \
            --gid ${CSHELL_GID} \
            --no-create-home \
            --disabled-password \
            --home "${CSHELL_HOME}" \
            --gecos "Checkpoint Agent" \
            --shell "/bin/false" \
            --disabled-login \
            "${CSHELL_USER}" 2>/dev/null || true
   fi
   # adjust file and directory permissions
   # create homedir 
   test -d "${CSHELL_HOME}" || mkdir -p "${CSHELL_HOME}"
   chown -R ${CSHELL_USER}:${CSHELL_GROUP} "${CSHELL_HOME}"
   chmod -R u=rwx,g=rwx,o= "$CSHELL_HOME"
}


# build required chroot file system structure + scripts
buildFS()
{
   cd "${CHROOT}" >&2 || die "could not chdir to ${CHROOT}" 

   # for sharing X11 with the host
   mkdir -p tmp/.X11-unix

   # for leaving cshell_install.sh happy
   mkdir -p "${CHROOT}/${CSHELL_HOME}/.config"

   # for showing date right when in shell mode inside chroot
   echo "TZ=${TZ}; export TZ" >> root/.profile

   # getting the last version of the agents installation scripts
   # from the firewall
   rm -f snx_install.sh cshell_install.sh
   if wget --no-check-certificate "https://${VPN}/SNX/INSTALL/snx_install.sh"
   then 
      wget --no-check-certificate "https://${VPN}/SNX/INSTALL/cshell_install.sh" || die "could not download cshell_install.sh"
   else
      wget --no-check-certificate "https://${VPN}/${SSLVPN}/SNX/INSTALL/snx_install.sh" || die "could not download snx_install.sh"
      wget --no-check-certificate "https://${VPN}/${SSLVPN}/SNX/INSTALL/cshell_install.sh" || die "could not download cshell_install.sh"
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

   # script for finishing chroot setup already inside chroot
   cat <<-EOF9 > root/chroot_setup.sh
	#!/bin/bash

	# create cShell user
	# create group 
	addgroup --quiet --gid ${CSHELL_GID} ${CSHELL_GROUP} 2>/dev/null ||true
	# create user
	adduser --quiet \
	        --uid ${CSHELL_UID} \
	        --gid ${CSHELL_GID} \
	        --no-create-home \
	        --disabled-password \
	        --home "${CSHELL_HOME}" \
	        --gecos "Checkpoint Agent" \
	        "${CSHELL_USER}" 2>/dev/null || true

        # adjust file and directory permissions
        # create homedir 
        test  -d "${CSHELL_HOME}" || mkdir -p "${CSHELL_HOME}"
        chown -R ${CSHELL_USER}:${CSHELL_GROUP} "${CSHELL_HOME}"
        chmod -R u=rwx,g=rwx,o= "$CSHELL_HOME"

	# create a who apt diversion for the fake one not being replaced
	# by security updates inside chroot
	dpkg-divert --divert /usr/bin/who.old --no-rename /usr/bin/who
	
	# needed packages
	apt -y install libstdc++5 libx11-6 libpam0g libnss3-tools openjdk-11-jre procps net-tools bzip2
	# clean APT chroot cache
	apt clean
	
	# install SNX and CShell
	/root/snx_install.sh
	echo "Installing CShell" >&2
	DISPLAY=${DISPLAY} PATH=/nopatch:$PATH /root/cshell_install.sh 
	
	exit 0
	EOF9

        # directory with stub commands for cshell_install.sh
	mkdir nopatch

        # fake certutil
        # -H returns 1 (test installed)
        # otherwise 0
   	cat <<-'EOF22' > nopatch/certutil
	#!/bin/bash
	if [[ "$1" == "-H" ]]
	then
	   exit 1
	else
	   exit 0
	fi
	EOF22

   # fake xterm and xhost 
   # since they are not needed inside chroot
   # both return 0
   ln -s ../sbin/modprobe nopatch/xhost
   ln -s ../sbin/modprobe nopatch/xterm

   # fake barebones Mozilla/Firefox profile
   # just enough to make cshell_install.sh happy
   mkdir -p home/${CSHELL_USER}/.mozilla/firefox/3ui8lv6m.default-release
   touch home/${CSHELL_USER}/.mozilla/firefox/3ui8lv6m.default-release/cert9.db
   cat <<-'EOF23' > home/${CSHELL_USER}/.mozilla/firefox/installs.ini
	Path=3ui8lv6m.default-release
	Default=3ui8lv6m.default-release
	EOF23

   # creates a subshell
   # to avoid possible pwd complications
   # in the case of an error
   ( 
   # add profiles.ini to keep variations of cshell_install.sh happy
   cd home/${CSHELL_USER}/.mozilla/firefox/
   ln -s installs.ini profiles.ini
   )

   chmod a+rx usr/bin/who sbin/modprobe root/chroot_setup.sh root/snx_install.sh root/cshell_install.sh nopatch/certutil
}


# create chroot fstab for sharing kernel 
# internals and directories/files with the host
FstabMount()
{
   # fstab for building chroot
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


# change DNS for resolvconf/systemd-resolved /run file
# for sharing DNS resolver configuration between chroot and host
fixDNS()
{
   # fix resolv.conf for resolvconf
   # shared resolv.conf between host and chroot via /run/
   rm -f etc/resolv.conf
   cd etc || die "could not enter ${CHROOT}/etc"

   # Debian - resolvconf
   if [[ ${DEB} -eq 1 ]]
   then
      ln -s ../run/resolvconf/resolv.conf resolv.conf
   fi

   # RH - systemd-resolved
   if [[ ${RH} -eq 1 ]]
   then
      ln -s ../run/systemd/resolve/stub-resolv.conf resolv.conf
   fi

   cd ..
}


# try to create GNOME autorun file similar to CShell
# but for all users instead of one user private profile
# on the host system
GnomeAutoRun()
{
   # directory for starting apps upon X11 login
   # /etc/xdg/autostart/
   if [ -d "$(dirname ${XDGAUTO})" ]
   then
      # XDGAUTO="/etc/xdg/autostart/cshell.desktop"
      cat > "${XDGAUTO}" <<-EOF11
	[Desktop Entry]
	Type=Application
	Name=cshell
	Exec=sudo ${INSTALLSCRIPT} -s -c ${CHROOT} start
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

   else
      echo "Was not able to create Gnome autorun desktop entry for CShell" >&2
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
    if [[ SSLVPN != "sslvpn" ]]
    then
       echo "SSLVPN=${SSLVPN}" >> "${CONFFILE}"
    fi
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

   # if Firefox installed
   for DIR in "/usr/lib/firefox" "/usr/lib64/firefox" "/usr/lib/firefox-esr" "/usr/lib64/firefox-esr"
   do
      if [[ -d "${DIR}" ]]
      then
         # if policies file not already installed
         if [[ ! -f ${DIR}/distribution/policies.json ]] || grep CShell_Certificate ${DIR}/distribution/policies.json &> /dev/null
         then
            # flag as installed
            PolInstalled=1

            # aparently present in Debian, nevertheless
            mkdir -p ${DIR}/distribution 2> /dev/null

            # create JSON policy file
            # Accepting CShell certificate

            cat <<-EOF14 > ${DIR}/distribution/policies.json
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

         fi
      fi
   done

   # if Firefox policy installed
   if [[ $PolInstalled -eq 1 ]]
   then
      # if Firefox running
      if pgrep firefox &>/dev/null
      then
         echo "Please restart Firefox" >&2
      fi
            
      echo "Firefox policy created for accepting https://localhost:14186 certificate" >&2
      echo "If using other browser than firefox" >&2
   fi
}


# last leg inside chroot
#
# minimal house keeping and user messages
# after finishing chroot setup
chrootEnd()
{
   local ROOTHOME

   # do the last leg of setup inside chroot
   doChroot /bin/bash --login -pf "/root/chroot_setup.sh"

   # if sucessful installation
   if isCShellRunning && [[ -f "${CHROOT}/usr/bin/snx" ]]
   then
      # delete temporary setup scripts from chroot's root home
      ROOTHOME="${CHROOT}/root"
      rm -f "${ROOTHOME}/chroot_setup.sh" "${ROOTHOME}/cshell_install.sh" "${ROOTHOME}/snx_install.sh" "${ROOTHOME}/nopatch"

      # copy this script to /usr/local/bin
      cp "${SCRIPT}" "${INSTALLSCRIPT}"
      chmod a+rx "${INSTALLSCRIPT}"

      # create /etc/vpn.conf
      createConfFile

      # install Gnome autorun file
      # last thing to run
      GnomeAutoRun

      echo "chroot setup done." >&2
      echo "${SCRIPT} copied to ${INSTALLSCRIPT}" >&2
      echo >&2

      # install Policy for CShell localhost certificate
      FirefoxPolicy

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
   # dont put inside ""
   doGetOpts $*

   # clean all the getopts logic from the arguments
   # leaving only commands
   shift $((OPTIND-1))

   # after options check, as we want help to work.
   PreCheck "$1"

   if [[ ${install} -eq false ]]
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
main $*

 
