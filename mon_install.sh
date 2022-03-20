#!/bin/bash
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[33m"
ST="\033[0m"

function updateTelegrafConfig {
# expected directory of telegarf configuration as first param (/etc/telegraf)
# backup current config 
sudo cp $1/telegraf.conf $1/$(date +"%F-%H:%M:%S")-telegraf.conf.orig
sudo rm -rf $1/telegraf.conf
echo "# Global Agent Configuration
[agent]
  hostname = \"${server_name}\" # set this to a name you want to identify your node in the grafana dashboard
  flush_interval = \"15s\"
  interval = \"15s\"
# Input Plugins
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false
[[inputs.disk]]
  ignore_fs = [\"devtmpfs\", \"devfs\"]
[[inputs.io]]
[[inputs.mem]]
[[inputs.net]]
[[inputs.nstat]]
[[inputs.system]]
[[inputs.swap]]
[[inputs.netstat]]
[[inputs.linux_sysctl_fs]]
[[inputs.processes]]
[[inputs.interrupts]]
[[inputs.kernel]]
[[inputs.diskio]]
# Output Plugin InfluxDB
[[outputs.influxdb]]
  database = \"${mon_serv_db_name}\"
  urls = [ \"${mon_serv_url}\" ] # example http://yourownmonitoringnode:8086
  username = \"${mon_serv_username}\" # your database username
  password = \"${mon_serv_passwd}\" # your database user's password
[[inputs.exec]]
  commands = [\"sudo su -c ${mon_umee_path}/monitor.sh -s /bin/bash ${user}\"] # change home and username to the useraccount your validator runs at
  interval = \"15s\"
  timeout = \"5s\"
  data_format = \"influx\"
  data_type = \"integer\"
[[inputs.exec]]
  commands = [\"sudo su -c${mon_umee_path}/monitor_bal.sh -s /bin/bash ${user}\"] 
  interval = \"15s\"
  timeout = \"5s\"
  data_format = \"influx\"
  data_type = \"integer\"
"> $HOME/telegraf.conf
sudo mv $HOME/telegraf.conf $1/telegraf.conf
sudo systemctl restart telegraf
}

function installTelegraf {
# install telegraf
if [ -n  "$(ps -A | grep telegraf)" ]
then
echo "Telegaraf installed already"
else 
echo "Begin to install telegraf"
sudo apt update
sudo apt -y install curl jq bc
# install telegraf
sudo cat <<EOF | sudo tee /etc/apt/sources.list.d/influxdata.list
deb https://repos.influxdata.com/ubuntu bionic stable
EOF
sudo curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add -
sudo apt update
sudo apt -y install telegraf
sudo systemctl enable --now telegraf
sudo systemctl is-enabled telegraf
# systemctl status telegraf
# make the telegraf user sudo and adm to be able to execute scripts as umee user
sudo adduser telegraf sudo
sudo adduser telegraf adm
sudo -- bash -c 'echo "telegraf ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers'
fi 
}

function showNode75Logo {
echo -e "$GREEN _   _           _     ______ _____ 
| \ | |         | |   |____  | ____|
|  \| | ___   __| | ___   / /| |__  
| . \` |/ _ \ / _\` |/ _ \ / / |___ \ 
| |\  | (_) | (_| |  __// /   ___) |
|_| \_|\___/ \__,_|\___/_/   |____/ $ST"
}

showNode75Logo
sleep 1s
user=$(whoami)
echo -e "\nThis script will install UMEE monitoring tools on your server for user $GREEN${user}$ST"
echo -ne "Continue? (y/n):"
until [ -n  "$item" ]
do
read item
case "$item" in
    y|Y) echo "Start installing"
        ;;
    n|N) echo "Exit"
        exit 0
        ;;
    *) echo -ne "Please type answer (y/n):"
        item=""
esac
done

echo -e "Install Telegarf agent:"
# sudo apt update
# sudo apt install curl jq -y
installTelegraf

sleep 1s

cd $HOME
COS_BIN_NAME=$(which umeed)
echo -e "Umee binary: ${GREEN}${COS_BIN_NAME}${ST}"

repo="$HOME/mon_umee"
echo -e "\nClone monitoring project repo to: ${repo}"
if ! [ -d $repo ]
then
  echo "Clone repository"
  git clone https://github.com/shurinov/mon_umee.git
else
  echo "Repository exist. Stash local changes and pull"
  cd $repo
  git stash
  git pull
  cd $HOME
fi


echo -e "Create $repo/mon_var.sh with node settings"
if [ -e $repo/mon_var.sh ]
then
  echo "File $repo/mon_var.sh is exist"
else
  cp $repo/mon_var_template.sh $repo/mon_var.sh
fi

chmod +x $repo/mon_var.sh
chmod +x $repo/monitor.sh
chmod +x $repo/monitor_bal.sh



item=""
until [ -n  "$item" ]
do
echo -ne "Insert this server unic name (example: validator_name-rpc) "
read server_name
echo -ne "Do you confirm using ${server_name} as server unic name? (y/n):"
read item
case "$item" in
    y|Y);;
    *) item=""
esac
done

item=""
until [ -n  "$item" ]
do
echo -ne "Insert Monitoring service database name (example: umeemetricsdb):"
read mon_serv_db_name
echo -ne "Do you confirm using ${mon_serv_db_name} as database name? (y/n):"
read item
case "$item" in
    y|Y);;
    *) item=""
esac
done


item=""
until [ -n  "$item" ]
do
echo -ne "Insert Monitoring service URL (example: http://123.45.67.89:8086):"
read mon_serv_url
echo -ne "Do you confirm using ${mon_serv_url} as service URL? (y/n):"
read item
case "$item" in
    y|Y);;
    *) item=""
esac
done

item=""
until [ -n  "$item" ]
do
echo -ne "Insert Monitoring service username (example: metrics):"
read mon_serv_username
echo -ne "Do you confirm using ${mon_serv_username} as service username? (y/n):"
read item
case "$item" in
    y|Y);;
    *) item=""
esac
done

item=""
until [ -n  "$item" ]
do
echo -ne "Insert Monitoring service password (example: password):"
read mon_serv_passwd
echo -ne "Do you confirm using ${mon_serv_passwd} as service password? (y/n):"
read item
case "$item" in
    y|Y);;
    *) item=""
esac
done

mon_umee_path="${repo}"
updateTelegrafConfig /etc/telegraf
echo -e "Project github: https://github.com/shurinov/mon_umee.git"
echo -e "UMEE monitoring tools will be successfully install after check node parameters in mon_var.sh!"
echo -e "Edit it by ${RED}nano $repo/mon_var.sh${ST}"
echo -e "Telegraf configuration file: ${YELLOW}/etc/telegraf/telegraf.conf${ST}"
echo -e "You could check telegraf logs: ${YELLOW}sudo journalctl -u telegraf -f${ST}"
