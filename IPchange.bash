#!/bin/bash

NODEIP=123

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

get_ip
sed -i '9s/.*/bind='"$NODEIP"'/' .3dcoin/3dcoin.conf