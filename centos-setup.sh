#!/bin/bash
#
# centos-setup.sh
#
# (c) Niki Kovacs 2020 <info@microlinux.fr>

# Enterprise Linux version
VERSION="el7"

# Répertoire actuel
CWD=$(pwd)

# Utilisateurs définis
USERS="$(ls -A /home)"

# Utilisateur Admin
ADMIN=$(getent passwd 1000 | cut -d: -f 1)

# Supprimer ces packages
CRUFT=$(egrep -v '(^\#)|(^\s+$)' ${CWD}/${VERSION}/yum/useless-packages.txt)

# Installez ces packages
EXTRA=$(egrep -v '(^\#)|(^\s+$)' ${CWD}/${VERSION}/yum/extra-packages.txt)

# utilisateurs définis
USERS="$(ls -A /home)"

# miroirs
ELREPO="https://elrepo.org/linux/elrepo/${VERSION}/x86_64/RPMS"
CISOFY="https://packages.cisofy.com"

# Log
LOG="/tmp/$(basename "${0}" .sh).log"
echo > ${LOG}

usage() {
  echo "Usage: ${0} OPTION"
  echo 'CentOS 7.x post-install configuration for servers.'
  echo 'Options:'
  echo '  -1, --shell    Configure shell: Bash, Vim, console, etc.'
  echo '  -2, --repos    Setup official and third-party repositories.'
  echo '  -3, --extra    Install enhanced base system.'
  echo '  -4, --prune    Remove useless packages.'
  echo '  -5, --logs     Enable admin user to access system logs.'
  echo '  -6, --ipv4     Disable IPv6 and reconfigure basic services.'
  echo '  -7, --sudo     Configure persistent password for sudo.'
  echo '  -8, --setup    Perform all of the above in one go.'
  echo '  -9, --strip    Revert back to enhanced base system.'
  echo '  -h, --help     Show this message.'
  echo "Logs are written to ${LOG}."
}

configure_shell() {
  # Installez des invites de commande personnalisées et quelques d'alias astucieux.
  echo 'Configuration du shell Bash pour root.'
  cat ${CWD}/${VERSION}/bash/bashrc-root > /root/.bashrc
  echo 'Configuration du shell Bash pour les utilisateurs.'
  cat ${CWD}/${VERSION}/bash/bashrc-users > /etc/skel/.bashrc
  # Les utilisateurs existants pourraient vouloir l'utiliser.
  if [ ! -z "${USERS}" ]
  then
    for USER in ${USERS}
    do
      cat ${CWD}/${VERSION}/bash/bashrc-users > /home/${USER}/.bashrc
      chown ${USER}:${USER} /home/${USER}/.bashrc
    done
  fi
  # Ajoutez quelques astucieux system-wide options pour Vim.
  echo 'Configuring de Vim.'
  cat ${CWD}/${VERSION}/vim/vimrc > /etc/vimrc
  # Définissez l'anglais comme langue principale du système.
  echo 'configuring du system locale.'
  localectl set-locale LANG=en_US.UTF8
  # Définir la résolution de la console
  if [ -f /boot/grub2/grub.cfg ]
  then
    echo 'Configuring console resolution.'
    sed -i -e 's/rhgb quiet/nomodeset quiet vga=791/g' /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg >> ${LOG} 2>&1
  fi
}

configure_repos() {
  # Activez les dépôts [base], [updates] et [extra] avec une priorité de 1.
  echo 'Configuring official package repositories.'
  cat ${CWD}/${VERSION}/yum/CentOS-Base.repo > /etc/yum.repos.d/CentOS-Base.repo
  sed -i -e 's/installonly_limit=5/installonly_limit=2/g' /etc/yum.conf
  # Activez le dépôt [cr] avec une priorité de 1.
  echo 'Configuring CR package repository.'
  cat ${CWD}/${VERSION}/yum/CentOS-CR.repo > /etc/yum.repos.d/CentOS-CR.repo
  # Activez le dépôt [sclo] avec une priorité de 1.
  echo 'Configuring SCLo package repositories.'
  if ! rpm -q centos-release-scl > /dev/null 2>&1
  then
    yum -y install centos-release-scl >> ${LOG} 2>&1
  fi
  cat ${CWD}/${VERSION}/yum/CentOS-SCLo-scl-rh.repo > /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo
  cat ${CWD}/${VERSION}/yum/CentOS-SCLo-scl.repo > /etc/yum.repos.d/CentOS-SCLo-scl.repo
  # Activez Delta RPM.
  if ! rpm -q deltarpm > /dev/null 2>&1
  then
    echo 'Enabling Delta RPM.'
    yum -y install deltarpm >> ${LOG} 2>&1
  fi
  # mise à jour initiale
  echo 'Performing initial update.'
  echo 'This might take a moment...'
  yum -y update >> ${LOG} 2>&1
  # Instalation Yum-Priorities plugin
  if ! rpm -q yum-plugin-priorities > /dev/null 2>&1
  then
    echo 'Installing Yum-Priorities plugin.'
    yum -y install yum-plugin-priorities >> ${LOG} 2>&1
  fi
  # Activez le dépôt [epel] avec une priorité de 10.
  echo 'Configuring EPEL package repository.'
  if ! rpm -q epel-release > /dev/null 2>&1
  then
    yum -y install epel-release >> ${LOG} 2>&1
  fi
  cat ${CWD}/${VERSION}/yum/epel.repo > /etc/yum.repos.d/epel.repo
  cat ${CWD}/${VERSION}/yum/epel-testing.repo > /etc/yum.repos.d/epel-testing.repo
  # Configurer les dépôts [elrepo] et [elrepo-kernel] sans les activez.
  echo 'Configuring ELRepo package repositories.'
  if ! rpm -q elrepo-release > /dev/null 2>&1
  then
    yum -y localinstall \
    ${ELREPO}/elrepo-release-7.0-4.${VERSION}.elrepo.noarch.rpm >> ${LOG} 2>&1
  fi
  cat ${CWD}/${VERSION}/yum/elrepo.repo > /etc/yum.repos.d/elrepo.repo
  # Activez le dépôt [lynis] avec une priorité de 5.
  echo 'Configuring Lynis package repository.'
  if [ ! -f /etc/yum.repos.d/lynis.repo ]
  then
    rpm --import ${CISOFY}/keys/cisofy-software-rpms-public.key >> ${LOG} 2>&1
  fi
  cat ${CWD}/${VERSION}/yum/lynis.repo > /etc/yum.repos.d/lynis.repo
}

install_extras() {
  echo 'Fetching missing packages from Core package group.' 
  yum group mark remove "Core" >> ${LOG} 2>&1
  yum -y group install "Core" >> ${LOG} 2>&1
  echo 'Core package group installed on the system.'
  echo 'Installing Base package group.'
  echo 'This might take a moment...'
  yum group mark remove "Base" >> ${LOG} 2>&1
  yum -y group install "Base" >> ${LOG} 2>&1
  echo 'Base package group installed on the system.'
  echo 'Installing some additional packages.'
  for PACKAGE in ${EXTRA}
  do
    if ! rpm -q ${PACKAGE} > /dev/null 2>&1
    then
      echo "Installing package: ${PACKAGE}"
      yum -y install ${PACKAGE} >> ${LOG} 2>&1
    fi
  done
  echo 'All additional packages installed on the system.'
}

remove_cruft() {
  echo 'Suppression des packages inutiles du système.'
  for PACKAGE in ${CRUFT}
  do
    if rpm -q ${PACKAGE} > /dev/null 2>&1
    then
      echo "Suppression du package: ${PACKAGE}"
      yum -y remove ${PACKAGE} >> ${LOG} 2>&1
      if [ "${?}" -ne 0 ]
        then
        echo "Impossible de supprimer le package ${PACKAGE}." >&2
        exit 1
      fi
    fi
  done
  echo 'Tous les packages inutiles supprimés du système.'
}

remove_cruft() {
  echo 'Removing useless packages from the system.'
  for PACKAGE in ${CRUFT}
  do
    if rpm -q ${PACKAGE} > /dev/null 2>&1
    then
      echo "Removing package: ${PACKAGE}"
      yum -y remove ${PACKAGE} >> ${LOG} 2>&1
      if [ "${?}" -ne 0 ]
        then
        echo "Could not remove package ${PACKAGE}." >&2
        exit 1
      fi
    fi
  done
  echo 'All useless packages removed from the system.'
}


disable_ipv6() {
  # Désactiver IPv6
  echo 'Disabling IPv6.'
  cat ${CWD}/${VERSION}/sysctl.d/disable-ipv6.conf > /etc/sysctl.d/disable-ipv6.conf
  sysctl -p --load /etc/sysctl.d/disable-ipv6.conf >> $LOG 2>&1
  # Reconfigurer SSH 
  if [ -f /etc/ssh/sshd_config ]
  then
    echo 'Configuring SSH server for IPv4 only.'
    sed -i -e 's/#AddressFamily any/AddressFamily inet/g' /etc/ssh/sshd_config
    sed -i -e 's/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/g' /etc/ssh/sshd_config
  fi
  # Reconfigurer Postfix
  if [ -f /etc/postfix/main.cf ]
  then
    echo 'Configuring Postfix server for IPv4 only.'
    sed -i -e 's/inet_protocols = all/inet_protocols = ipv4/g' /etc/postfix/main.cf
    systemctl restart postfix
  fi
  # Reconstruire initrd
  echo 'Rebuilding initial ramdisk.'
  dracut -f -v >> $LOG 2>&1
}

configure_sudo() {
  # Configurer un mot de passe persistant pour sudo.
  if grep timestamp_timeout /etc/sudoers > /dev/null 2>&1
  then
    echo 'Persistent password for sudo already configured.'
  else
    echo 'Configuring persistent password for sudo.'
    echo >> /etc/sudoers
    echo '# Timeout' >> /etc/sudoers
    echo 'Defaults timestamp_timeout=-1' >> /etc/sudoers
  fi
}

strip_system() {
  # Supprimez tous les packages qui ne font pas partie du système de base amélioré.
  echo 'Stripping system.'
  local TMP='/tmp'
  local PKGLIST="${TMP}/pkglist"
  local PKGINFO="${TMP}/pkg_base"
  rpm -qa --queryformat '%{NAME}\n' | sort > ${PKGLIST}
  PACKAGES=$(egrep -v '(^\#)|(^\s+$)' $PKGLIST)
  rm -rf ${PKGLIST} ${PKGINFO}
  mkdir ${PKGINFO}
  unset REMOVE
  echo 'Creating database.'
  BASE=$(egrep -v '(^\#)|(^\s+$)' ${CWD}/${VERSION}/yum/enhanced-base.txt)
  for PACKAGE in ${BASE}
  do
    touch ${PKGINFO}/${PACKAGE}
  done
  for PACKAGE in ${PACKAGES}
  do
    if [ -r ${PKGINFO}/${PACKAGE} ]
    then
      continue
    else
      REMOVE="${REMOVE} ${PACKAGE}"
    fi
  done
  if [ ! -z "${REMOVE}" ]
  then
    for PACKAGE in ${REMOVE}
    do
      if rpm -q ${PACKAGE} > /dev/null 2>&1
      then
        echo "Removing package: ${PACKAGE}"
        yum -y remove ${PACKAGE} >> ${LOG} 2>&1
      fi
    done
  fi
  configure_repos
  install_extras
  remove_cruft
  rm -rf ${PKGLIST} ${PKGINFO}
}

# Assurez-vous que le script est exécuté avec des privilèges de superutilisateur.
if [[ "${UID}" -ne 0 ]]
then
  echo 'Please run with sudo or as root.' >&2
  exit 1
fi

# Vérifier les paramètres.
if [[ "${#}" -ne 1 ]]
then
  usage
  exit 1
fi
OPTION="${1}"
case "${OPTION}" in
  -1|--shell) 
    configure_shell
    ;;
  -2|--repos) 
    configure_repos
    ;;
  -3|--extra) 
    install_extras
    ;;
  -4|--prune) 
    remove_cruft
    ;;
  -5|--logs) 
    configure_logs
    ;;
  -6|--ipv4) 
    disable_ipv6
    ;;
  -7|--sudo) 
    configure_sudo
    ;;
  -8|--setup) 
    configure_shell
    configure_repos
    install_extras
    remove_cruft
    configure_logs
    disable_ipv6
    configure_sudo
    ;;
  -9|--strip) 
    strip_system
    ;;
  -h|--help) 
    usage
    exit 0
    ;;
  ?*) 
    usage
    exit 1
esac

exit 0



