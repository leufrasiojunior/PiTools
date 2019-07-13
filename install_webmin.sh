#!/bin/bash

###VARIABLES###

LOG="/var/log/log_install.log"
PKG_MANAGER="apt-get"
PKG_CACHE="/var/lib/apt/lists/"
UPDATE_PKG_CACHE="${PKG_MANAGER} update"
PKG_INSTALL="${PKG_MANAGER} --yes --no-install-recommends install"
PKG_COUNT="${PKG_MANAGER} -s -o Debug::NoLocking=true upgrade | grep -c ^Inst || true"


#If any error, exit install
set -e

update_package_cache() {
  #Running apt-get update/upgrade with minimal output can cause some issues with
  #requiring user input

  #Check to see if apt-get update has already been run today
  #it needs to have been run at least once on new installs!
  timestamp=$(stat -c %Y ${PKG_CACHE})
  timestampAsDate=$(date -d @"${timestamp}" "+%b %e")
  today=$(date "+%b %e")


  if [ ! "${today}" == "${timestampAsDate}" ]; then
    #update package lists
    echo ":::"
    echo -n "::: ${PKG_MANAGER} update has not been run today. Running now..."
    $SUDO ${UPDATE_PKG_CACHE} &> /dev/null
    echo " done!"
  fi
}

notify_package_updates_available() {
  # Let user know if they have outdated packages on their system and
  # advise them to run a package update at soonest possible.
  echo ":::"
  echo -n "::: Checking ${PKG_MANAGER} for upgraded packages...."
  updatesToInstall=$(eval "${PKG_COUNT}")
  echo " done!"
  echo ":::"
  if [[ ${updatesToInstall} -eq "0" ]]; then
    echo "::: Your system is up to date! Continuing with Webmin installation..."
  else
    echo "::: There are ${updatesToInstall} updates available for your system!"
    echo "::: We recommend you update your OS after installing Webmin! "
    echo ":::"
  fi
}

GetInstallWeb(){
local TEMPFILE=(mktemp)
	echo "Obtendo o link de download... Aguarde!"
	curl -sSL http://www.webmin.com/deb.html &>> "${TEMPFILE}"
		CMD_DOWN=$(grep 'wget' "${TEMPFILE}" | sed 's/<[^>]*>//g' | head -1 | cut -d " " -f2)
	
	echo "${CMD_DOWN}"
	echo "O link está correto (s/n): "
		read link
	
	echo "${link}"
		link2=$(echo "$link" | tr 'N' 'n')
	echo $link2
	
	if [[ "$link2" = "n" ]]; then
			read -p "Favor, obter o link no site http://www.webmin.com/download.html e colar aqui: " CMD_DOWN
	fi
	sudo rm "${TEMPFILE}"

}

InstallWeb(){
wget "${CMD_DOWN} -O webmin.deb"
dpkg -i webmin.deb
rm webmin.deb
}


dependencies(){
#install dependencies
debconf-apt-progress -- apt-get --yes --install-recommends install perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python
}

update_package_cache(){
	#Running apt-get update / upgrade with minimal output can cause some problems
	#requesting user input
	# Check if apt update started today.
	#Must need to run at least once in new installations!
  timestamp=$(stat -c %Y ${PKG_CACHE})
  timestampAsDate=$(date -d @"${timestamp}" "+%b %e")
  today=$(date "+%b %e")


  if [ ! "${today}" == "${timestampAsDate}" ]; then
    #update package lists
    echo ":::"
    echo -n "::: apt-get update has not been run today. Running now..."
    $SUDO apt-get update &>> ${LOG}
    echo " done!"
  fi
}

main(){

    ######## FIRST CHECK ########
    # Must be root to install
    echo ":::"
    if [[ $EUID -eq 0 ]];then
        echo "::: You are root."
    else
        echo "::: sudo will be used for the install."
        # Check if it is actually installed
        # If it isn't, exit because the install cannot complete
        if [[ $(dpkg-query -s sudo) ]];then
            export SUDO="sudo"
            export SUDOE="sudo -E"
        else
            echo "::: Please install sudo or run this as root."
            exit 1
        fi
    fi


    # Update package cache
    update_package_cache || exit 1

    # Notify user of package availability
    notify_package_updates_available
	
	#Install Dependencies
	dependencies
	
	#Install Webmin
	InstallWeb
}

if [[ "${WEBMIN_TEST}" != true ]] ; then
  main "$@"
fi
