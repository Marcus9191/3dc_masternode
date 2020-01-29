#!/bin/bash
TMP_FOLDER=$(mktemp -d)
CONFIGFOLDER=$HOME/.3dcoin
CONFIG_FILE='3dcoin.conf'
COIN_DAEMON='3dcoind'
COIN_CLI='3dcoin-cli'
COIN_PATH='/usr/local/bin/'
COIN_NAME='3dcoin'
COIN_PORT=6695
NODEIP=123
RPC_PORT=6694
COIN_TGZ=https://github.com/Marcus9191/3dc_masternode/raw/master/3dcoin-linux.zip
COIN_UPD=https://github.com/Marcus9191/3dc_masternode/raw/master/cust-upd-3dc.sh
COIN_DESTUCK=https://raw.githubusercontent.com/Marcus9191/Scripts/master/destuck.bash
COIN_ZIP=$(echo $COIN_TGZ | awk -F'/' '{print $NF}')

ARGS="$#"
COINKEY=$3
USERBASE=$1
PASSWORD=$2

BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m" 
PURPLE="\033[0;35m"
RED='\033[0;31m'
GREEN="\033[0;32m"
NC='\033[0m'
MAG='\e[1;35m'

function setup_node() {
  unset NODE_IPS
  check_args
  check_distro
  check_user
  create_user
  fixSSH
  apt_update
  apt_install
  welcome
  download_node
  get_ip
  custom_exe
  it_exists
  create_config
  configure_systemd
  configure_update
  configure_destuck
  important_information
  finish
}

function check_args() {
  if test $ARGS -lt 3; then
    echo "Usage: "$0" username password key"
    exit 1
  fi
}

function check_distro() {
  if [[ $(lsb_release -i) != *Ubuntu* ]]; then
    echo -e "${RED}You are not running Ubuntu. This script is meant for Ubuntu.${NC}"
    exit 1
  fi
}

function check_user() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}$0 must be run as root.${NC}"
    exit 1
  fi
}

function create_user() {
  IFS=_ read -a tmp <<< $(uname -n)

  if [ -z "${tmp[2]}" ]
  then
        IFS=- read -a tmp <<< $(uname -n)
  fi

  if [ -z "${tmp[2]}" ]
  then
        IFS=- read -a tmp <<< $(uname -n)
  else
    user=${USERBASE}"_"${tmp[2]}
  fi

  if [ -z "${tmp[2]}" ]
  then
    user=$USERBASE
  fi

  echo -n "["$(date +"%T")"] Adding user "$user"... "
  useradd $user
  echo "Added"

  echo -n "[$(date +"%T")] Changing password... "
  echo $user:$PASSWORD | chpasswd
  echo "Changed."

  echo -n "[$(date +"%T")] Disabling root login... "
  sed -i '/^PermitRootLogin[ \t]\+\w\+$/{ s//PermitRootLogin no/g; }' /etc/ssh/sshd_config
  service ssh restart
  echo "Disabled"
}

function welcome() {
  base64 -d <<<"H4sICCgmslsAAzNkY29pbi50eHQAjVC5DQAxDOo9BTLzef/2gOSe5qS4CJhgYgU4rQJGdZ8IwVcMWCm0oAkaBpM20DZYBk1ZK6G3tuB2vISzrE/qv9U3WkChVGqykVaoln6P3jMzO/XsB+oCwu9KXC4BAAA=" | gunzip
  echo -e "${GREEN}Masternode installation script $COIN_NAME ${NC}"
  sleep 3
}

function fixSSH() {
    echo 'd /run/sshd 0755 root root' > /usr/lib/tmpfiles.d/sshd.conf
}

function apt_update() {
  echo
  echo -e "${GREEN}Checking and installing operating system updates. It may take awhile ...${NC}"
  apt-get update
  if [[ -f /var/run/reboot-required ]]
    then echo -e "${RED}Warning:${NC}${GREEN}some updates require a reboot${NC}"
    echo -e "${GREEN}Do you want to reboot at the end of masternode installation process?${NC}"
    echo -e "${GREEN}(${NC}${RED} y ${NC} ${GREEN}/${NC}${RED} n ${NC}${GREEN})${NC}"
    read rebootsys
    case $rebootsys in
    y*)
      REBOOTSYS=y
      ;;
    n*)
      REBOOTSYS=n
      ;;
    *)
      echo -e "${GREEN}Your choice,${NC}${CYAN} $rebootsys${NC},${GREEN} is not valid. Assuming${NC}${RED} n ${NC}"
      REBOOTSYS=n
      sleep 5
      ;;
    esac
  fi
}

function apt_install() {
  apt-get -y install zip unzip curl wget systemd cron nano 
}

function check_swap() {
  SWAPSIZE=$(cat /proc/meminfo | grep SwapTotal | awk '{print $2}')
  FREESPACE=$(df / | tail -1 | awk '{print $4}')
  if [ $SWAPSIZE -lt 4000000 ]
    then if [ $FREESPACE -gt 6000000 ]
      then dd if=/dev/zero of=/bigfile.swap bs=250MB count=16 
      chmod 600 /bigfile.swap
      mkswap /bigfile.swap
      swapon /bigfile.swap
      echo '/bigfile.swap none swap sw 0 0' >> /etc/fstab
      else echo 'Swap seems smaller than recommended. It cannot be increased because of lack of space'
      fi
  fi  
}

function download_node() {
  SOURCEBIN="BIN"
  echo -e "${GREEN}Downloading and Installing VPS $COIN_NAME Daemon${NC}"
  sleep 5
  cd $TMP_FOLDER >/dev/null 2>&1
  wget -q $COIN_TGZ
  if [[ $? -ne 0 ]]; then
   echo -e 'Error downloading node. Please contact support'
   exit 1
  fi
  if [[ -f $COIN_PATH$COIN_DAEMON ]]; then
  unzip -j $COIN_ZIP *$COIN_DAEMON >/dev/null 2>&1
  MD5SUMOLD=$(md5sum $COIN_PATH$COIN_DAEMON | awk '{print $1}')
  MD5SUMNEW=$(md5sum $COIN_DAEMON | awk '{print $1}')
  pidof $COIN_DAEMON >/dev/null 2>&1
  RC=$?
   if [[ "$MD5SUMOLD" != "$MD5SUMNEW" && "$RC" -eq 0 ]]; then
     echo -e 'Those daemon(s) are about to die'
     echo -e $(ps axo cmd:100 | grep $COIN_DAEMON | grep -v grep)
     echo -e 'If systemd service or a custom check is not implemented, take care of their restart'
     for service in $(systemctl | grep $COIN_NAME | awk '{ print $1 }'); do systemctl stop $service >/dev/null 2>&1; done
     sleep 3
     RESTARTSYSD=Y
   fi
   if [[ "$MD5SUMOLD" != "$MD5SUMNEW" ]]
    then unzip -o -j $COIN_ZIP *$COIN_DAEMON *$COIN_CLI -d $COIN_PATH >/dev/null 2>&1
    chmod +x $COIN_PATH$COIN_DAEMON $COIN_PATH$COIN_CLI
    if [[ "$RESTARTSYSD" == "Y" ]]
    then for service in $(systemctl | grep $COIN_NAME | awk '{ print $1 }'); do systemctl start $service >/dev/null 2>&1; done
    fi
    sleep 3
   fi
  else unzip -o -j $COIN_ZIP *$COIN_DAEMON *$COIN_CLI -d $COIN_PATH >/dev/null 2>&1
  chmod +x $COIN_PATH$COIN_DAEMON $COIN_PATH$COIN_CLI
  fi
  cd ~ >/dev/null 2>&1
  rm -rf $TMP_FOLDER >/dev/null 2>&1
}

function get_ip() {
  unset NODE_IPS
  declare -a NODE_IPS
  for ips in $(ip a | grep inet | awk '{print $2}' | cut -f1 -d "/")
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 4 -sk https://v4.ident.me/))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP have been found."
      echo -e "Please press ${YELLOW}ENTER${NC} ${GREEN}to use ${NC}${YELLOW}${NODE_IPS[0]}${NC}" 
      echo -e "${GREEN}Type${NC} ${YELLOW}1${NC}${GREEN} for the second one${NC} ${YELLOW}${NODE_IPS[1]}${NC} ${GREEN}and so on..."
      echo -e "If a $COIN_NAME masternode/node is already running on this host, we recommend to press ENTER"
      echo -e "At the end of installation process, the script will ask you if you want to install another masternode${NC}"
      INDEX=
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      echo ${NODE_IPS[@]} | grep ${NODE_IPS[$choose_ip]} >/dev/null 2>&1
      if [[ $? -ne 0 ]];
        then echo "Choosen value not in list"
        get_ip
      fi
      IP_SELECT=$choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
    IP_SELECT=
  fi
}

function custom_exe() {
  if [[ -f $COIN_PATH$COIN_DAEMON ]]
    then echo '#!/bin/bash' > $COIN_PATH$COIN_CLI$IP_SELECT.sh
    echo "$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER$IP_SELECT/$CONFIG_FILE -datadir=$CONFIGFOLDER$IP_SELECT \$@" >> $COIN_PATH$COIN_CLI$IP_SELECT.sh
    chmod 755 $COIN_PATH$COIN_CLI$IP_SELECT.sh
    echo '#!/bin/bash' > $COIN_PATH$COIN_DAEMON$IP_SELECT.sh
    echo "$COIN_PATH$COIN_DAEMON -conf=$CONFIGFOLDER$IP_SELECT/$CONFIG_FILE -datadir=$CONFIGFOLDER$IP_SELECT \$@" >> $COIN_PATH$COIN_DAEMON$IP_SELECT.sh
    chmod 755 $COIN_PATH$COIN_DAEMON$IP_SELECT.sh

    else echo -e "{RED}Warnig!{NC}{GREEN} $COIN_DAEMON not found in $COIN_PATH. Something wrong happened during installation"
    echo -e "Type {RED} r {GREEN} to try again the installation"
    echo -e "Type {RED} e {GREEN} to exit installation script{NC}"
    read tryagain
    case $tryagain in
      r*)
      source-or-bin 
      ;;
      e*)
      echo "Installation failed, exiting ...."
      exit 4
      ;;
      *)
      echo "Your choice, {RED}$tryagain{NC} is not valid"
      sleep 3
      custom_exe
      ;;
    esac
  fi 
}

function it_exists() {
  if [[ -d $CONFIGFOLDER$IP_SELECT ]]; then
    echo
    echo -e "${GREEN}It seems a $COIN_NAME instance is already installed in $CONFIGFOLDER$IP_SELECT"
    echo -e "Save the masternodeprivkey if you want to use it again${NC}${RED}"
    echo -e $(cat $CONFIGFOLDER$IP_SELECT/$CONFIG_FILE|grep masternodeprivkey |cut -d "=" -f2)
    echo -e "${NC}${GREEN}Type${NC} ${YELLOW}y${NC} ${GREEN}to scratch it (be carefull, if your balace is different from 0, also your wallet will be erased)"
    echo -e "Type${NC} ${YELLOW}n${NC} ${GREEN}to exit (check your balance if you are not sure it 0${NC}"
  read -e ANSWER
  case $ANSWER in
      y)      
            systemctl stop $COIN_NAME$IP_SELECT.service >/dev/null 2>&1
            systemctl disable $COIN_NAME$IP_SELECT.service >/dev/null 2>&1
            kill -9 $(pidof $COIN_DAEMON) >/dev/null 2>&1
            rm -rf $CONFIGFOLDER$IP_SELECT
            ;;
      n)      
            exit 0
            ;;
      *)
            echo -e "${GREEN} $ANSWER is not an option ${NC}"
            sleep 3
            it_exists
            ;; 
  esac
  fi
}

function create_config() {
  mkdir $CONFIGFOLDER$IP_SELECT >/dev/null 2>&1
  RPCUSER=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w10 | head -n1)
  RPCPASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w22 | head -n1)
  if [[ -z "$IP_SELECT" ]]; then
   RPC_PORT=$RPC_PORT
   else let RPC_PORT=$RPC_PORT-$IP_SELECT
  fi
  if [[ "$NODEIP" =~ [A-Za-z] ]]; then
    NODEIP=[$NODEIP]
    RPCBIND=[::1]
   else RPCBIND=127.0.0.1
  fi
  cat << EOF > $CONFIGFOLDER$IP_SELECT/$CONFIG_FILE
#Uncomment RPC credentials if you don't want to use local cookie for auth
#rpcuser=$RPCUSER
#rpcpassword=$RPCPASSWORD
rpcport=$RPC_PORT
server=1
daemon=1
port=$COIN_PORT
maxconnections=64
bind=$NODEIP
rpcbind=$RPCBIND
rpcallow=$RPCBIND
masternode=1
externalip=$NODEIP:$COIN_PORT
masternodeprivkey=$COINKEY
addnode=206.189.72.203
addnode=206.189.41.191
addnode=165.227.197.115
addnode=167.99.87.86
addnode=159.65.201.222
addnode=159.65.148.226
addnode=165.227.38.214
addnode=159.65.167.79
addnode=159.65.90.101
addnode=128.199.218.139
addnode=174.138.3.33
addnode=159.203.167.75
addnode=138.68.102.67
EOF
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/$COIN_NAME$IP_SELECT.service
[Unit]
Description=$COIN_NAME$IP_SELECT service
After=network.target
[Service]
User=root
Group=root
Type=forking
ExecStart=$COIN_PATH$COIN_DAEMON -daemon -conf=$CONFIGFOLDER$IP_SELECT/$CONFIG_FILE -datadir=$CONFIGFOLDER$IP_SELECT
ExecStop=-$COIN_PATH$COIN_CLI -conf=$CONFIGFOLDER$IP_SELECT/$CONFIG_FILE -datadir=$CONFIGFOLDER$IP_SELECT stop
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $COIN_NAME$IP_SELECT.service >/dev/null 2>&1
systemctl start $COIN_NAME$IP_SELECT.service
sleep 8
netstat -napt | grep LISTEN | grep $NODEIP | grep $COIN_DAEMON >/dev/null 2>&1
 if [[ $? -ne 0 ]]; then
   ERRSTATUS=TRUE
 fi
}

function configure_update() {
    ORA=$(echo $((1 + $RANDOM % 23)))
    MIN=$(echo $((1 + $RANDOM % 59)))
    wget -q $COIN_UPD -O $COIN_PATH/cust-upd-3dc.sh
    chmod +x $COIN_PATH/cust-upd-3dc.sh
    crontab -l > /tmp/cron2upd
    echo "$MIN $ORA * * * $COIN_PATH/cust-upd-3dc.sh $SOURCEBIN" >> /tmp/cron2upd
    crontab /tmp/cron2upd >/dev/null 2>&1
    echo -e "${GREEN}/tmp/cron2upd is a temporary copy of crontab${NC}"
    sleep 5
}

function configure_destuck() {
    mkdir /usr/local/bin/Masternode/
    wget -q $COIN_DESTUCK -O $COIN_PATH/daemon_check.sh
    chmod +x $COIN_PATH/daemon_check.sh
    crontab -l > /tmp/cron2upd
    echo "*/30 * * * * $COIN_PATH/daemon_check.sh" >> /tmp/cron2upd
    crontab /tmp/cron2upd >/dev/null 2>&1
    echo -e "${GREEN}/tmp/cron2upd is a temporary copy of crontab${NC}"
    sleep 5
}

function important_information() {
  echo
  echo -e "${BLUE}================================================================================================================================${NC}"
  echo -e "${CYAN}$COIN_NAME linux  vps setup${NC}"
  echo -e "${BLUE}================================================================================================================================${NC}"
  echo -e "${GREEN}$COIN_NAME Masternode is up and running listening on port: ${NC}${RED}$COIN_PORT${NC}."
  echo -e "${GREEN}Configuration file is: ${NC}${RED}$CONFIGFOLDER$IP_SELECT/$CONFIG_FILE${NC}"
  echo -e "${GREEN}VPS_IP: ${NC}${RED}$NODEIP:$COIN_PORT${NC}"
  echo -e "${GREEN}MASTERNODE GENKEY is: ${NC}${RED}$COINKEY${NC}"
  echo -e "${BLUE}================================================================================================================================"
  echo -e "${CYAN}Stop, start and check your $COIN_NAME instance${NC}"
  echo -e "${BLUE}================================================================================================================================${NC}"
  echo -e "${PURPLE}Instance  start${NC}"
  echo -e "${GREEN}systemctl start $COIN_NAME$IP_SELECT.service${NC}"
  echo -e "${PURPLE}Instance  stop${NC}"
  echo -e "${GREEN}systemctl stop $COIN_NAME$IP_SELECT.service${NC}"
  echo -e "${PURPLE}Instance  check${NC}"
  echo -e "${GREEN}systemctl status $COIN_NAME$IP_SELECT.service${NC}"
  echo -e "${BLUE}================================================================================================================================${NC}"
  echo -e "${CYAN}Ensure Node is fully SYNCED with BLOCKCHAIN before start your masternode from hot wallet .${NC}"
  echo -e "${BLUE}================================================================================================================================${NC}"
  echo -e "${GREEN}$COIN_CLI$IP_SELECT.sh mnsync status${NC}"
  echo -e "${GREEN}$COIN_CLI -datadir=$CONFIGFOLDER$IP_SELECT mnsync status${NC}"
  echo -e "${YELLOW}It is expected this line: \"IsBlockchainSynced\": true ${NC}"
  echo -e "${BLUE}================================================================================================================================${NC}"
  echo -e "${CYAN}Check masternode status${NC}"
  echo -e "${BLUE}================================================================================================================================${NC}"
  echo -e "${GREEN}$COIN_CLI -datadir=$CONFIGFOLDER$IP_SELECT masternode status${NC}"
  echo -e "${GREEN}$COIN_CLI$IP_SELECT.sh masternode status${NC}"
  echo -e "${GREEN}$COIN_CLI -datadir=$CONFIGFOLDER$IP_SELECT getinfo${NC}"
  echo -e "${GREEN}$COIN_CLI$IP_SELECT.sh getinfo${NC}"
  echo -e "${BLUE}================================================================================================================================${NC}"
  if [[ "$ERRSTATUS" == "TRUE" ]]; then
    echo -e "${RED}$COIN_NAME$IP_SELECT seems not running, please investigate. Check its status by running the following commands as root:${NC}"
    echo -e "systemctl status $COIN_NAME$IP_SELECT.service"
    echo -e "${RED}You can restart it by firing following command (as root):${NC}"
    echo -e "${GREEN}systemctl start $COIN_NAME$IP_SELECT.service${NC}"
    echo -e "${RED}Check errors by runnig following commands:${NC}"
    echo -e "${GREEN}less /var/log/syslog${NC}"
    echo -e "${GREEN}journalctl -xe${NC}"
  fi
  unset NODE_IPS
}

function finish() {
  if [[ "$REBOOTSYS" == "y" ]]
   then echo -e "Good bye!"
   sleep 3
   shutdown -r now
  fi
  if [[ "$REBOOTSYS" == "n" && -f /var/run/reboot-required ]]
   then echo -e "${RED}Keep in mind, this server still need a reboot${NC}"
  fi
   echo "Good bye!"
}

##### Main #####
setup_node
