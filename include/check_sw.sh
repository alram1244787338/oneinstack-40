#!/bin/bash
# Author:  Alpha Eva <kaneawk AT gmail.com>
#
# Notes: OneinStack for CentOS/RedHat 7+ Debian 9+ and Ubuntu 16+
#
# Project home page:
#       https://oneinstack.com
#       https://github.com/oneinstack/oneinstack

installDepsDebian() {
  echo "${CMSG}Removing the conflicting packages...${CEND}"
  if [ "${apache_flag}" == 'y' ]; then
    killall apache2
    pkgList="apache2 apache2-doc libsodium-dev apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker php5 php5-common php5-cgi php5-cli php5-mysql php5-curl php5-gd"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  if [[ "${db_option}" =~ ^[1-9]$|^1[0-2]$ ]]; then
    pkgList="mysql-client mysql-server mysql-common libsodium-dev mysql-server-core-5.5 mysql-client-5.5 mariadb-client mariadb-server mariadb-common"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  echo "${CMSG}Installing dependencies packages...${CEND}"
  apt-get -y update
  apt-get -y autoremove
  apt-get -yf install
  export DEBIAN_FRONTEND=noninteractive

  # critical security updates
  grep security /etc/apt/sources.list > /tmp/security.sources.list
  apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list

  # Install needed packages
  case "${Debian_ver}" in
    9|10|11|12|13)
      pkgList="debian-keyring libsodium-dev debian-archive-keyring libxpm-dev build-essential gcc g++ make cmake autoconf libbz2-dev libjpeg62-turbo-dev libjpeg-dev libpng-dev libgd-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libc-client2007e-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libncurses5 libncurses5-dev libaio1 libaio-dev numactl libreadline-dev curl libcurl3-gnutls libcurl4-openssl-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn11 libidn11-dev openssl net-tools libssl-dev libtool libevent-dev bison re2c libsasl2-dev libxslt1-dev libicu-dev locales patch vim zip unzip tmux htop bc dc expect libexpat1-dev libonig-dev libtirpc-dev rsync git lsof lrzsz rsyslog cron logrotate chrony libsqlite3-dev psmisc wget sysv-rc apt-transport-https ca-certificates software-properties-common gnupg ufw"
      ;;
    *)
      echo "${CFAILURE}Your system Debian ${Debian_ver} are not supported!${CEND}"
      kill -9 $$; exit 1;
      ;;
  esac
  failedPkgs=""
  for Package in ${pkgList}; do
    if ! apt-get --no-install-recommends -y install ${Package} > /dev/null 2>&1; then
      echo "${CWARNING}Warning: Failed to install package '${Package}' on Debian ${Debian_ver}${CEND}"
      failedPkgs="${failedPkgs} ${Package}"
    fi
  done
  if [ -n "${failedPkgs}" ]; then
    echo "${CWARNING}The following packages failed to install on Debian ${Debian_ver}:${failedPkgs}${CEND}"
    echo "${CWARNING}Some features may not work correctly. Please check the log for details.${CEND}"
  fi
}

installDepsRHEL() {
  [ -e '/etc/yum.conf' ] && sed -i 's@^exclude@#exclude@' /etc/yum.conf
  if [ "${RHEL_ver}" == '9' ]; then
    if [[ "${Platform}" =~ "rhel" ]]; then
      subscription-manager repos --enable codeready-builder-for-rhel-9-${ARCH}-rpms
      dnf -y install chrony oniguruma-devel rpcgen
    elif [[ "${Platform}" =~ "ol" ]]; then
      dnf config-manager --set-enabled ol9_codeready_builder
      dnf -y install chrony oniguruma-devel rpcgen
    else
      dnf -y --enablerepo=crb install chrony oniguruma-devel rpcgen
    fi
    systemctl enable chronyd
  elif [ "${RHEL_ver}" == '8' ]; then
    if [[ "${Platform}" =~ "rhel" ]]; then
      subscription-manager repos --enable codeready-builder-for-rhel-8-${ARCH}-rpms
      dnf -y install chrony oniguruma-devel rpcgen
    elif [[ "${Platform}" =~ "ol" ]]; then
      dnf config-manager --set-enabled ol8_codeready_builder
      dnf -y install chrony oniguruma-devel rpcgen
    else
      [ -z "`grep -w epel /etc/yum.repos.d/*.repo`" ] && yum -y install epel-release
      if grep -qw "^\[PowerTools\]" /etc/yum.repos.d/*.repo; then
        dnf -y --enablerepo=PowerTools install chrony oniguruma-devel rpcgen
      elif grep -qw "^\[powertools\]" /etc/yum.repos.d/*.repo; then
        dnf -y --enablerepo=powertools install chrony oniguruma-devel rpcgen
      fi
    fi
    systemctl enable chronyd
  elif [ "${RHEL_ver}" == '7' ]; then
    [ -z "`grep -w epel /etc/yum.repos.d/*.repo`" ] && yum -y install epel-release
    yum -y groupremove "Basic Web Server" "MySQL Database server" "MySQL Database client"
  fi

  if [ "${RHEL_ver}" == '9' ]; then
    [ ! -e "/usr/lib64/libtinfo.so.5" ] && ln -s /usr/lib64/libtinfo.so.6 /usr/lib64/libtinfo.so.5
    [ ! -e "/usr/lib64/libncurses.so.5" ] && ln -s /usr/lib64/libncurses.so.6 /usr/lib64/libncurses.so.5
  fi

  echo "${CMSG}Installing dependencies packages...${CEND}"
  # Install needed packages
  pkgList="perl-FindBin deltarpm libsodium-dev drpm gcc gcc-c++ make cmake autoconf libjpeg libjpeg-dev libjpeg-devel libbz2-dev libjpeg-turbo libjpeg-turbo-devel libpng libpng-devel libxml2 libxml2-devel zlib zlib-devel libzip libzip-devel glibc glibc-devel krb5-devel libcurl4-openssl-dev libc-client libc-client-devel glib2 glib2-devel bzip2 bzip2-devel ncurses ncurses-devel ncurses-compat-libs libaio numactl numactl-libs readline-devel curl curl-devel e2fsprogs e2fsprogs-devel krb5-devel libidn libidn-devel openssl openssl-devel net-tools libxslt-devel libssl-dev libicu-devel libevent-devel libtool libtool-ltdl bison gd-devel vim-enhanced pcre-devel libmcrypt libsqlite3-dev libmcrypt-devel mhash mhash-devel mcrypt zip unzip chrony oniguruma-devel rpcgen sqlite-devel sysstat patch bc expect expat-devel perl-devel oniguruma oniguruma-devel libtirpc-devel nss libnsl rsync rsyslog git lsof lrzsz psmisc wget which libatomic tmux chkconfig firewalld"
  failedPkgs=""
  for Package in ${pkgList}; do
    if ! yum -y install ${Package} > /dev/null 2>&1; then
      echo "${CWARNING}Warning: Failed to install package '${Package}' on RHEL ${RHEL_ver}${CEND}"
      failedPkgs="${failedPkgs} ${Package}"
    fi
  done
  if [ -n "${failedPkgs}" ]; then
    echo "${CWARNING}The following packages failed to install on RHEL ${RHEL_ver}:${failedPkgs}${CEND}"
    echo "${CWARNING}Some features may not work correctly. Please check the log for details.${CEND}"
  fi
  [ ${RHEL_ver} -lt 8 >/dev/null 2>&1 ] && yum -y install cmake3

  yum -y update bash openssl glibc
}

installDepsUbuntu() {
  # Uninstall the conflicting software
  echo "${CMSG}Removing the conflicting packages...${CEND}"
  if [ "${apache_flag}" == 'y' ]; then
    killall apache2
    pkgList="apache2 apache2-doc apache2-utils apache2.2-common apache2.2-bin apache2-mpm-prefork apache2-doc apache2-mpm-worker php5 php5-common php5-cgi php5-cli php5-mysql php5-curl php5-gd libncurses5"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  if [[ "${db_option}" =~ ^[1-9]$|^1[0-2]$ ]]; then
    pkgList="mysql-client mysql-server mysql-common mysql-server-core-5.5 mysql-client-5.5 mariadb-client mariadb-server mariadb-common"
    for Package in ${pkgList};do
      apt-get -y purge ${Package}
    done
    dpkg -l | grep ^rc | awk '{print $2}' | xargs dpkg -P
  fi

  echo "${CMSG}Installing dependencies packages...${CEND}"
  apt-get -y update
  apt-get -y autoremove
  apt-get -yf install
  export DEBIAN_FRONTEND=noninteractive

  # Ubuntu 22: ensure libicu70 is available (needed by PHP intl extension)
  # Do NOT hard-pin libglib2.0-0 — the pinned version 2.72.1-1 is not
  # present in all 22.04 point releases and causes apt to bail out.
  if [[ "${Ubuntu_ver}" =~ ^22$ ]]; then
    apt-get -y --allow-downgrades install libicu70 libxml2-dev
  fi

  # critical security updates
  grep security /etc/apt/sources.list > /tmp/security.sources.list
  apt-get -y upgrade -o Dir::Etc::SourceList=/tmp/security.sources.list

  # Install needed packages — version-specific lists to avoid dead/renamed packages
  case "${Ubuntu_ver}" in
    24|25|26)
      # Ubuntu 24.04+: libncurses5*, libc-client2007e-dev, libpng12*, libjpeg8*
      # are gone; libcurl3-gnutls replaced by libcurl4t64; sysv-rc removed
      pkgList="libperl-dev pkg-config libsodium-dev libbz2-dev libxslt-dev libjpeg-dev libxml2-dev libxpm-dev libfreetype-dev debian-keyring debian-archive-keyring build-essential gcc g++ make cmake autoconf libpng-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libglib2.0-0t64 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libaio1 libaio-dev numactl libreadline-dev curl libcurl4-openssl-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn2-0 libidn2-dev openssl net-tools libssl-dev libtool libevent-dev re2c libsasl2-dev libxslt1-dev libicu-dev libsqlite3-dev bison patch vim zip unzip tmux htop bc dc expect libexpat1-dev rsyslog libonig-dev libtirpc-dev libnss3 rsync git lsof lrzsz chrony psmisc wget apt-transport-https ca-certificates software-properties-common gnupg ufw libfreetype6-dev libexif-dev gettext-dev libgmp-dev libncurses-dev"
      ;;
    22)
      # Ubuntu 22.04: libpng12*, libpng3, libjpeg8*, libcloog-ppl1, libcurl3-gnutls,
      # libcurl4-gnutls-dev are gone or renamed. libncurses5* still available.
      pkgList="libperl-dev pkg-config libsodium-dev libbz2-dev libxslt-dev libjpeg-dev libxml2-dev libxpm-dev libfreetype-dev debian-keyring debian-archive-keyring build-essential gcc g++ make cmake autoconf libpng-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libc-client2007e-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libncurses5 libncurses5-dev libaio1 libaio-dev numactl libreadline-dev curl libcurl4-openssl-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn11 libidn11-dev openssl net-tools libssl-dev libtool libevent-dev re2c libsasl2-dev libxslt1-dev libicu-dev libsqlite3-dev bison patch vim zip unzip tmux htop bc dc expect libexpat1-dev rsyslog libonig-dev libtirpc-dev libnss3 rsync git lsof lrzsz chrony psmisc wget apt-transport-https ca-certificates software-properties-common gnupg ufw libfreetype6-dev libexif-dev gettext-dev libgmp-dev"
      ;;
    16|18|20)
      # Ubuntu 16.04–20.04: keep legacy package names
      pkgList="libperl-dev pkg-config libsodium-dev libbz2-dev libxslt-dev libjpeg-dev libxml2-dev libxpm-dev libfreetype-dev debian-keyring debian-archive-keyring build-essential gcc g++ make cmake autoconf libjpeg8 libjpeg8-dev libpng-dev libpng12-0 libpng12-dev libxml2 libxml2-dev zlib1g zlib1g-dev libc6 libc6-dev libc-client2007e-dev libglib2.0-0 libglib2.0-dev bzip2 libzip-dev libbz2-1.0 libncurses5 libncurses5-dev libaio1 libaio-dev numactl libreadline-dev curl libcurl3-gnutls libcurl4-gnutls-dev libcurl4-openssl-dev e2fsprogs libkrb5-3 libkrb5-dev libltdl-dev libidn11 libidn11-dev openssl net-tools libssl-dev libtool libevent-dev re2c libsasl2-dev libxslt1-dev libicu-dev libsqlite3-dev libcloog-ppl1 bison patch vim zip unzip tmux htop bc dc expect libexpat1-dev rsyslog libonig-dev libtirpc-dev libnss3 rsync git lsof lrzsz chrony psmisc wget sysv-rc apt-transport-https ca-certificates software-properties-common gnupg ufw libiconv-dev libfreetype6-dev libexif-dev gettext-dev libgmp-dev"
      ;;
    *)
      echo "${CFAILURE}Your system Ubuntu ${Ubuntu_ver} is not supported!${CEND}"
      kill -9 $$; exit 1;
      ;;
  esac
  export DEBIAN_FRONTEND=noninteractive
  failedPkgs=""
  for Package in ${pkgList}; do
    if ! apt-get --no-install-recommends -y install ${Package} > /dev/null 2>&1; then
      echo "${CWARNING}Warning: Failed to install package '${Package}' on Ubuntu ${Ubuntu_ver}${CEND}"
      failedPkgs="${failedPkgs} ${Package}"
    fi
  done
  if [ -n "${failedPkgs}" ]; then
    echo "${CWARNING}The following packages failed to install on Ubuntu ${Ubuntu_ver}:${failedPkgs}${CEND}"
    echo "${CWARNING}Some features may not work correctly. Please check the log for details.${CEND}"
  fi
}

installDepsBySrc() {
  pushd ${oneinstack_dir}/src > /dev/null
  if ! command -v icu-config > /dev/null 2>&1 || icu-config --version | grep '^3.' || [ "${Ubuntu_ver}" == "20" ]; then
    tar xzf icu4c-${icu4c_ver}-src.tgz
    pushd icu/source > /dev/null
    ./configure --prefix=/usr/local
    if ! make -j ${THREAD} || ! make install; then
      echo "${CFAILURE}Error: Failed to build icu4c from source${CEND}"
      popd > /dev/null
      popd > /dev/null
      return 1
    fi
    popd > /dev/null
    rm -rf icu
  fi

  popd > /dev/null

  # Verify critical dependencies are actually available before writing the
  # initialisation marker.  If any of these are missing the install was NOT
  # successful and we must NOT create ~/.oneinstack — otherwise the next run
  # will skip dependency installation entirely.
  local criticalCmds="lsof gcc make curl"
  local missingCmds=""
  for cmd in ${criticalCmds}; do
    if ! command -v ${cmd} > /dev/null 2>&1; then
      missingCmds="${missingCmds} ${cmd}"
    fi
  done

  if [ -n "${missingCmds}" ]; then
    echo "${CFAILURE}Error: Critical commands are missing after dependency installation:${missingCmds}${CEND}"
    echo "${CFAILURE}Initialisation marker (~/.oneinstack) was NOT written.${CEND}"
    echo "${CFAILURE}Please fix the missing dependencies and re-run the installer.${CEND}"
    kill -9 $$; exit 1;
  fi

  # All critical checks passed — write the initialisation marker
  echo 'already initialize' > ~/.oneinstack
}
