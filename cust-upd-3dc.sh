#!/bin/bash
TMP_FOLDER=$(mktemp -d)
COIN_TGZ=https://github.com/Marcus9191/3dc_masternode/raw/master/3dcoin-linux.zip
COIN_DAEMON='3dcoind'
COIN_CLI='3dcoin-cli'
COIN_PATH='/usr/local/bin/'
COIN_NAME=3dcoin
COIN_ZIP=$(echo $COIN_TGZ | awk -F'/' '{print $NF}')

case $1 in
 BIN*)
  cd $TMP_FOLDER >/dev/null 2>&1
  wget -q $COIN_TGZ
  if [[ $? -ne 0 ]]; then
   echo -e 'Error downloading node.'
   exit 1
  fi
  if [[ -f $COIN_PATH$COIN_DAEMON ]]; then
  unzip -j $COIN_ZIP *$COIN_DAEMON >/dev/null 2>&1
  MD5SUMOLD=$(md5sum $COIN_PATH$COIN_DAEMON | awk '{print $1}')
  MD5SUMNEW=$(md5sum $COIN_DAEMON | awk '{print $1}')
  pidof $COIN_DAEMON
  RC=$?
  if [[ "$MD5SUMOLD" != "$MD5SUMNEW" && "$RC" -eq 0 ]]; then
     echo -e "Stop running instances"
     for service in $(systemctl | grep $COIN_NAME | awk '{ print $1 }')
      do systemctl stop $service >/dev/null 2>&1
     done
     sleep 3
     RESTARTSYSD=Y
   fi
  fi
  if [[ "$MD5SUMOLD" != "$MD5SUMNEW" ]];  then
  unzip -o -j $COIN_ZIP *$COIN_DAEMON *$COIN_CLI -d $COIN_PATH >/dev/null 2>&1
  chmod +x $COIN_PATH$COIN_DAEMON $COIN_PATH$COIN_CLI
  if [[ "$RESTARTSYSD" == "Y" ]]
  then echo -e "Restarting 3dcoin services"
  for service in $(systemctl -a | grep $COIN_NAME | awk '{ print $1 }')
   do systemctl start $service >/dev/null 2>&1
  done
  fi
  fi
  ;;
 SRC*)
  latestrelease=$(curl --silent https://api.github.com/repos/BlockchainTechLLC/3dcoin/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
  localrelease=$(3dcoin-cli -version | awk -F' ' '{print $NF}' | cut -d "-" -f1)
  if [ -z "$latestrelease" ] || [ "$latestrelease" == "$localrelease" ]
  then echo "$latestrelease ultima release dsponibile. $localrelease release installata."
  exit
  else rm -rf $HOME/3dcoin
  cd $HOME/
  git clone https://github.com/BlockchainTechLLC/3dcoin.git
  cd 3dcoin
  ./autogen.sh
  ./configure --disable-tests --disable-gui-tests --without-gui
  for service in $(systemctl | grep $COIN_NAME | awk '{ print $1 }')
   do systemctl stop $service >/dev/null 2>&1
  done
  sleep 10
  make install-strip
  for service in $(systemctl -a | grep $COIN_NAME | awk '{ print $1 }')
   do systemctl start $service >/dev/null 2>&1
  done
  fi
  ;;
esac
