#!/bin/bash 
#
# Rui Ribeiro doc_v1.50
#
# VPN client chroot'ed setup/wrapper for Debian/Ubuntu
# Checkpoint R80.10 and up
#
# Please fill VPN and VPNIP before using this script.
# SPLIT might or not have to be filled, depending on your needs 
# and Checkpoint VPN routes.
#
# first time run it as sudo ./vpn.sh -i
# Accept localhost certificate visiting https://localhost:14186/id
# Then open VPN URL to login/start the VPN
#
# It will get CShell and SNX installations scripts from the firewall,
# and install them. 
# CShell installation script patch included at the end of file. 
#
# non-chroot version not written intencionally. 
# SNX/CShell behave on odd ways ;
# the chroot is built to counter some of those behaviours
#
# CShell CheckPoint Java agent needs Java *and* X11 desktop rights
# binary SNX VPN client needs 32-bits environment
#
# tested with chroot Debian Bullseye 11 (32 bits)
# hosts: Debian 10, Debian 11, Ubuntu LTS 18.04, Ubuntu LTS 22.04
#

VERSION="v0.91"

# default chroot location (700 MB needed - 1.5GB while installing)
CHROOT="/opt/chroot"

# Checkpoint VPN address
# Fill VPN *and* VPNIP *before* using the script
VPN=""
VPNIP=""

# split VPN routing table if deleting VPN gateway is not enough
# if empty script will delete VPN gateway
SPLIT=""

# OS to deploy inside 32-bit chroot  
VARIANT="minbase"
RELEASE="bullseye" # Debian 11
REPO="http://deb.debian.org/debian/" # fastly repo

# used during initial chroot setup
# for chroot shell correct time
if [ -z "${TZ}" ]
then
   TZ='Europe/Lisbon'
fi

# URL for testing if split or full VPN
URL_VPN_TEST="https://www.debian.com"

# CShell writes in the display
if [ -z "${DISPLAY}" ]
then
   DISPLAY=":0.0"
fi
export DISPLAY

# dont bother with locales
export LC_ALL=C LANG=C

# script full PATH
SCRIPT=$(realpath "${BASH_SOURCE[0]}")
SCRIPTPATH=$(dirname $SCRIPT)
# script name
SCRIPTNAME=$(basename "${SCRIPT}")

# VPN interface
TUNSNX="tunsnx"

# GNOME autostart X11 file
XDGAUTO="/etc/xdg/autostart/cshell.desktop"

# script PATH upon successful setup
INSTALLSCRIPT="/usr/local/bin/${SCRIPTNAME}"

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

	${SCRIPTNAME} [-c|--chroot DIR][--proxy proxy_string] -i|--install
	${SCRIPTNAME} [--vpn FQDN][-c|--chroot DIR] start|stop|status
	${SCRIPTNAME} [-c|--chroot DIR] uninstall
	${SCRIPTNAME} disconnect|split|selfupdate
	${SCRIPTNAME} -h|--help
	${SCRIPTNAME} -v|--version
	
	-i|--install install mode - create chroot
	-c|--chroot  change default chroot ${CHROOT} directory
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
	
	${SCRIPTNAME} -d|--debug
	${SCRIPTNAME} [-c|--chroot DIR] shell|upgrade
	
	-d|--debug   bash debug mode on
	shell        bash shell inside chroot
	upgrade      OS upgrade inside chroot
	
	EOF1

   # exits after help
   exit 0
}

# DNS lookup: getent is installed by default
vpnlookup() 
{ 
   VPNIP=$(getent ahostsv4 "${VPN}" | awk 'NR==1 { print $1 } ' ) 
}

# complain to STDERR and exit with error
die() 
{ 
   echo "$*" >&2 
   exit 2 
}  

# optional arguments handling
needs_arg() 
{ 
   if [ -z "${OPTARG}" ]; 
   then 
      die "No arg for --$OPT option" 
   fi 
}

# arguments - script getopts options handling
doGetOpts()
{
   # install status flag
   install=false

   # process command line options
   while getopts dic:-:hv OPT
   do

      # long option: reformulate OPT and OPTARG
      if [ "${OPT}" = "-" ] 
      then   
         OPT="${OPTARG%%=*}"       # extract long option name
         OPTARG="${OPTARG#$OPT}"   # extract long option argument (may be empty)
         OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
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
         v | version )     echo "${VERSION}"         # script version
                           exit 0 ;;
         osver)            awk -F"=" '/^PRETTY_NAME/ { gsub("\"","");print $2 } ' /etc/os-release
                           exit 0 ;;
         d | debug )       set -x ;;                 # bash debug on
         h | help )        do_help ;;                # show help
         ??* )             die "Illegal option --${OPT}" ;;  # bad long option
         ? )               exit 2 ;;  # bad short option (error reported via getopts)
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
   if [ ! -f /etc/debian_version ]  
   then
      die "This script is for Debian/Ubuntu Linux based flavours only" 
   fi

   if ischroot
   then
      die "Do not run this script inside a chroot" 
   fi

   if [[ -z "${VPN}" ]] || [[ -z "${VPNIP}" ]]
   then
      die "Please fill in VPN and VPNIP with the DNS FQDN and the IP address of your Checkpoint VPN server"
   fi
}

# C/Unix convention - 0 success, 1 failed
isCShellRunning()
{
   local n

   # n = number of CShell process(es) - usually 1
   n=$(ps ax | grep CShell | grep -cv grep)

   # if zero processes
   if [[ $n -eq 0 ]]
   then
      # return false
      return 1
   else
      # return true
      return 0
   fi
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
         # mount using fstab inside chroot, all filesystems
         sudo mount --fstab "${CHROOT}/etc/fstab" -a
      fi
   fi
}

# umount chroot fs
umountChrootFS()
{
   # unmount chroot filesystems
   mount | grep "${CHROOT}" &> /dev/null

   # if mounted
   if [ $? -eq 0 ]
   then
      # there is no --fstab for umount
      sudo chroot "${CHROOT}" /usr/bin/umount -a 2> /dev/null

      # umount any leftover mount
      for i in $(mount | grep "${CHROOT}" | awk ' { print  $3 } ' )
      do
         sudo umount $i 2> /dev/null
         sudo umount -l $i 2> /dev/null
      done
      # force umount any leftover mount
      for i in $(mount | grep "${CHROOT}" | awk ' { print  $3 } ' )
      do
         sudo umount -l $i 2> /dev/null
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
      sudo ip route delete 0.0.0.0/1
      echo "default VPN gateway deleted" >&2
   else 
      # get local VPN given IP address
      IP=$(ip -4 addr show "${TUNSNX}" | awk '/inet/ { print $2 } ')

      # clean all VPN routes
      sudo ip route flush table main dev "${TUNSNX}"

      # create a new VPN routes according to $SPLIT
      for i in ${SPLIT}
      do
         sudo ip route add "$i" dev "${TUNSNX}" src "${IP}"
      done
   fi
}

# status command
showStatus()
{
   if ! isCShellRunning
   then
      # chroot/mount down, etc, not showing status
      die "CShell not running"
   else
      echo "CShell running"
   fi

   sudo "true"   # asking sudo password and caching it

   # host / chroot arquitecture
   echo
   echo -n "System: "
   awk -v ORS= -F"=" '/^PRETTY_NAME/ { gsub("\"","");print $2" " } ' /etc/os-release
   #uname -m
   arch
   echo -n "Chroot: "

   sudo chroot "${CHROOT}" /bin/bash --login -pf <<-EOF2 | awk -v ORS= -F"=" '/^PRETTY_NAME/ { gsub("\"","");print $2" " } '
	cat /etc/os-release
	EOF2

   # print--architecture and not uname because chroot shares the same kernel
   sudo chroot "${CHROOT}" /bin/bash --login -pf <<-EOF3
	/usr/bin/dpkg --print-architecture
	EOF3

   # SNX
   echo
   echo -n "SNX - installed              "
   sudo chroot "${CHROOT}"  snx -v 2> /dev/null | awk '/build/ { print $2 }'
   echo -n "SNX - available for download "
   #curl -skL "https://${VPN}/SNX/CSHELL/snx_ver.txt"
   wget -q -O- --no-check-certificate "https://${VPN}/SNX/CSHELL/snx_ver.txt"

   # IP connectivity
   echo
   # IP address VPN local address given
   IP=""
   IP=$(ip -4 addr show "${TUNSNX}" 2> /dev/null | awk '/inet/ { print $2 } ')

   echo -n "Linux  IP address: "
   hostname -I | awk '{print $1}'
   echo

   # if $IP not empty
   if [[ ! -z ${IP+x} ]]
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
   sudo bash -c 'cat /etc/snx/*.db' 2> /dev/null  # workaround for using * expansion inside sudo

   # DNS
   echo
   #resolvectl status
   cat /etc/resolv.conf
}

# kill Java daemon agent
killCShell()
{
   if isCShellRunning
   then
      # kill all java CShell agents (1)
      sudo kill -9 $(ps ax | grep CShell | grep -v grep | awk ' { print $1 } ')

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
   # all local apps - X auth
   if ! xhost + local:
   then
      echo "If there are not X11 desktop permissions, VPN won't run" >&2
      echo "run this while logged in to the graphic console," >&2
      echo "or in a terminal inside the graphic console" >&2
   fi

   # fixes potential resolv.conf/DNS issues inside chroot. 
   # Checkpoint software seems not mess up with it.
   # Unless a security update inside chroot damages it
   sudo rm -f "${CHROOT}/etc/resolv.conf"
   sudo ln -s ../run/resolvconf/resolv.conf "${CHROOT}/etc/resolv.conf"

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
   sudo chroot "${CHROOT}" /bin/bash --login -pf <<-EOF4
	DISPLAY=${DISPLAY} /usr/bin/cshell/launcher
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
   fi
}

# stop command
doStop()
{
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

   sudo chroot "${CHROOT}" /bin/bash --login -pf

   # dont need mounted filesystem with CShell agent down
   if ! isCShellRunning
   then
      umountChrootFS
   fi
}

# disconnect SNX/VPN session
doDisconnect()
{
   sudo chroot "${CHROOT}" /usr/bin/snx -d
}

# uninstall command
doUninstall()
{
   # stop SNX VPN session
   doDisconnect
   # stop CShell
   doStop

   # delete autorun file, chroot subdirectory and installed script
   sudo rm -f "${XDGAUTO}"
   sudo rm -rf "${CHROOT}"
   sudo rm -f "${INSTALLSCRIPT}" 

   echo "chroot+checkpoint software deleted" >&2
}

# upgrade OS inside chroot
Upgrade() {
   sudo chroot "${CHROOT}" /bin/bash --login -pf <<-EOF12
	apt update
	apt -y upgrade
	apt clean
	EOF12
}

# self update
selfUpdate() {
    cd /tmp
    # get latest release version
    VER=$(wget -q -O- --no-check-certificate https://api.github.com/repos/ruyrybeyro/chrootvpn/releases/latest | jq -r ".tag_name")
    echo "current version : ${VERSION}"
    if [[ ${VER} == "null" ]]
    then
       die "did not find any github release. Something went wrong"
    fi
    if [[ "${VER}" != "${VERSION}" ]]
    then
        echo "Found a new version of ${SCRIPTNAME}, updating myself..."

        if wget -O vpn.sh -o /dev/null "https://github.com/ruyrybeyro/chrootvpn/releases/download/${VER}/vpn.sh" 
        then
           # sed can use any char as separator for avoiding rule clashes
           sed -i "s/VPN=\"\"/VPN=\""${VPN}"\"/;s/VPNIP=\"\"/VPNIP=\""${VPNIP}"\"/;s@SPLIT=\"\"@SPLIT=\"${SPLIT}\"@" vpn.sh

           if [[ "${INSTALLSCRIPT}" != "${SCRIPT}"  ]]
           then
              sudo cp -f vpn.sh "${SCRIPT}" 
           fi

           sudo mv -f vpn.sh "${INSTALLSCRIPT}"

           sudo chmod a+rx "${INSTALLSCRIPT}" "${SCRIPT}"

           echo "scripts updated to version ${VER}"
           exit 0
        else
           die "could not fetch new version"
        fi

    else
       die "Already the latest version."
    fi
}

# check if chroot use is sane
PreCheck2()
{
   # if setup successfully finished, launcher has to be there
   if [[ -f "${CHROOT}/usr/bin/cshell/launcher" ]]
   then
      # for using/relaunching
      # call the script as regular user with sudo permissions
      if [ "${EUID}" -eq 0 ]
      then
         die "Do not run as root"
      fi
   else
      # if launcher not present something went wrong

      if [[ -d "${CHROOT}" ]]
      then
         umountChrootFS
         die "Something went wrong. Correct or to reinstall, run: ./${SCRIPTNAME} uninstall ; sudo ./${SCRIPTNAME} -i"
      else
         die "To install the chrooted Checkpoint client software, run: sudo ./${SCRIPTNAME} -i"
      fi
   fi
}
      
# arguments - command handling
argCommands()
{
   PreCheck2 

   case "$1" in

      start)        doStart ;;
      stop)         doStop ;;
      disconnect)   doDisconnect ;;
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
   # for setting chroot up, call the script as root/sudo script
   if [[ "${EUID}" -ne 0 ]] || [[ ${install} -eq false ]]
   then
      die "Please run as: sudo ./${SCRIPTNAME} --install [--chroot DIR]" 
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

# system update and package requirements
installPackages()
{
   # upgrade system
   apt -y update
   apt -y upgrade

   # install needed packages
   apt -y install debootstrap ca-certificates patch x11-xserver-utils jq wget
   # we want to make sure resolconf is the last one
   apt -y install resolvconf
   # clean APT host cache
   apt clean
}

# "bug/feature": check DNS health
checkDNS()
{
   if ! getent ahostsv4 "${VPN}" &> /dev/null
   then
      echo "DNS problems after installing resolvconf?" >&2
      echo "Not resolving ${VPN} DNS" >&2
      echo "Fix or reboot to fix" >&2
      exit 1
   fi	   
}

# creating the Debian minbase chroot
createChroot()
{
   echo "please wait..." >&2
   echo "slow command, often debootstrap hangs talking with Debian repositories" >&2
   echo "do ^C and start it over again if needed" >&2

   mkdir -p "${CHROOT}" || exit 1
   debootstrap --variant="${VARIANT}" --arch i386 "${RELEASE}" "${CHROOT}" "${REPO}"
   if [ $? -ne 0 ] || [ ! -d "${CHROOT}" ]
   then
      echo "chroot ${CHROOT} unsucessful creation" >&2
      echo "run sudo rm -rf ${CHROOT} and do it again" >&2
      exit 1
   fi
}

# build required chroot file system structure + scripts
buildFS()
{
   cd "${CHROOT}" >&2 || exit 1

   # for sharing X11 with the host
   mkdir -p tmp/.X11-unix

   # for leaving cshell_install.sh happy
   mkdir -p root/.config

   # for showing date right when in shell mode inside chroot
   echo "TZ=${TZ}; export TZ" >> root/.profile

   # getting the last version of the agents installation scripts
   # from the firewall
   rm -f snx_install.sh cshell_install.sh
   #curl -k "https://${VPN}/SNX/INSTALL/cshell_install.sh"
   wget --no-check-certificate "https://${VPN}/SNX/INSTALL/snx_install.sh"
   wget --no-check-certificate "https://${VPN}/SNX/INSTALL/cshell_install.sh"

   # doing the cshell_install.sh patches after the __DIFF__ line
   n=$(awk '/^__DIFF__/ {print NR ; exit 0; }' "${SCRIPT}")
   sed -e "1,${n}d" "${SCRIPT}" | patch cshell_install.sh
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
	echo -e "root\t:0"
	EOF6

   # hosts inside chroot
   cat <<-EOF7 > etc/hosts
	127.0.0.1 localhost
	${VPNIP} ${VPN}
	EOF7

   if [[ ! -z "${HOSTNAME}" ]]
   then
      echo -e "\n127.0.0.1 ${HOSTNAME}" >> etc/hosts
   fi

   # APT proxy for inside chroot
   if [[ ! -z "${CHROOTPROXY}" ]]
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
	# create a who apt diversion for the fake one not being replaced
	# by security updates inside chroot
	dpkg-divert --divert /usr/bin/who.old --no-rename /usr/bin/who
	
	# needed packages
	apt -y install libstdc++5 libx11-6 libpam0g libnss3-tools openjdk-11-jre procps net-tools bzip2
	# clean APT chroot cache
	apt clean
	
	# install SNX
	/root/snx_install.sh
	# install CShell
	echo "Installing CShell - ignore xhost errors" >&2
	DISPLAY=${DISPLAY} /root/cshell_install.sh
	
	exit 0
	EOF9

   chmod a+rx usr/bin/who sbin/modprobe root/chroot_setup.sh root/snx_install.sh root/cshell_install.sh
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

# change DNS for resolvconf /run file
# for sharing DNS resolver configuration between chroot and host
fixDNS()
{
   # fix resolv.conf for resolvconf
   # shared resolv.conf between host and chroot via /run/
   rm -f etc/resolv.conf
   cd etc
   ln -s ../run/resolvconf/resolv.conf resolv.conf
   cd ..
}

# try to create GNOME autorunn file similar to CShell
# but for all users instead of one user private profile
# on the host system
GnomeAutoRun()
{
   # directory for starting apps upon X11 login
   if [ -d $(dirname "${XDGAUTO}") ]
   then

      cat > "${XDGAUTO}" <<-EOF11
	[Desktop Entry]
	Type=Application
	Name=cshell
	Exec="${INSTALLSCRIPT}" -c "${CHROOT}" start
	Icon=
	Comment=
	X-GNOME-Autostart-enabled=true
	X-KDE-autostart-after=panel
	X-KDE-StartupNotify=false
	StartupNotify=false
	EOF11
      
      # message advising to add sudo without password
      # if you dont agent wont be started automatically after login
      # and ./vpn.sh start will be have to be done after each X11 login
      echo "Added graphical auto-start" >&2
      echo "For it to run, modify your /etc/sudoers for not asking for password" >&2
      echo "As in:" >&2
      echo >&2
      echo "%sudo	ALL=(ALL:ALL) NOPASSWD:ALL" >&2
      if [[ ! -z "${SUDO_USER+x}" ]]
      then
         echo "#or: " >&2
         echo "${SUDO_USER}	ALL=(ALL:ALL) NOPASSWD:ALL" >&2
      fi
      echo >&2

   else
      echo "Was not able to create Gnome autorun desktop entry for CShell" >&2
   fi
}

# last leg inside chroot
#
# minimal house keeping and user messages
# after finishing chroot setup
chrootEnd()
{
   # do the last leg of setup inside chroot
   chroot "${CHROOT}" /bin/bash --login -pf "/root/chroot_setup.sh"

   if isCShellRunning
   then
      # copy this script to /usr/local/bin
      cp "${SCRIPT}" "${INSTALLSCRIPT}"
      chmod a+rx "${INSTALLSCRIPT}"

      # install Gnome autorun file
      GnomeAutoRun

      echo "chroot setup done." >&2
      echo "${SCRIPT} copied to ${INSTALLSCRIPT}" >&2
      echo >&2

      # if localhost generated certificate not accepted, VPN auth will fail
      echo "open browser with https://localhost:14186/id to accept new localhost certificate" >&2
      echo "afterwards open browser at https://${VPN} to login into VPN" >&2

   else
      umountChrootFS
      die "Something went wrong. Chroot unmounted. Fix it or delete $CHROOT and run this script again" 
   fi
}

# main chroot install routine
InstallChroot()
{
   preFlight
   installPackages
   checkDNS
   createChroot
   buildFS
   FstabMount
   fixDNS
   chrootEnd
}

# main ()
main()
{

   # command options handling
   doGetOpts $*

   # after options check, as we want help to work.
   PreCheck

   # clean all the getopts logic from the arguments
   # leaving only commands
   shift $((OPTIND-1))

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

# patches for cshell_install.sh
# diff output, do not change bellow this line
__DIFF__
16,17c16,17
< AUTOSTART_DIR=
< USER_NAME=
---
> AUTOSTART_DIR=/root
> USER_NAME=root
333c333
< 		   return 1
---
> 		   return 0
340c340
<     STATUS=$?
---
>     STATUS=0
365c365
<     STATUS=$?
---
>     STATUS=0
455c455
< 
---
>     return 0
563c563
< 		exit 1
---
> 		#exit 1
575c575
< 		exit 1
---
> 		#exit 1
655c655
< STATUS=$?
---
> STATUS=0
726c726
< if [ $? -ne 0 ]
---
> if [ 0 -ne 0 ]
12076c12076
<  ÚIj@
\ No newline at end of file
---
>  ÚIj@
