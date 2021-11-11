# Umee node monitoring tool

Used toolset:
* [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/)
* [InfluxDB](https://www.influxdata.com/products/influxdb/)
* [Grafana](https://grafana.com/)

The project was inspired by Solana community monitoring from [Stakeconomy](https://github.com/stakeconomy/solanamonitoring) 

## Monitoring server installation 

### InfluxDB 

Install:
```
wget -qO- https://repos.influxdata.com/influxdb.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdb.gpg > /dev/null
export DISTRIB_ID=$(lsb_release -si); export DISTRIB_CODENAME=$(lsb_release -sc)
echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdb.gpg] https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/influxdb.list > /dev/null

sudo apt update && sudo apt install influxdb

sudo systemctl enable --now influxdb

sudo systemctl start influxdb

sudo systemctl status influxdb
```

Setup database (replace the password with a more secure one):
```
influx
> create database umeemetricsdb
> create user metrics with password 'password'
> grant WRITE on umeemetricsdb to metrics

```

You shold prepare for node agent installation:
* monitoring server ip 
* monitoring database username
* monitoring database user password

### Grafana

```
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"

sudo apt update -y
sudo apt install grafana -y

sudo systemctl daemon-reload

sudo systemctl enable --now grafana-server
sudo systemctl start grafana-server

# verify the status of the Grafana service with the following command:
sudo systemctl status grafana-server
```
Follow to **YOUR_MONITORING_SERVER_IP:3000** for setup grafana dashboard

Change default password for grafana user admin/admin to more safe

Load dashboard json file from this repo

![Dashboard screenshort](https://raw.githubusercontent.com/shurinov/mon_umee/main/resource/01_mon_umee_grafana_dashboard.png "Dashboard screenshort")

## Installation on a node

### By fast installation script

You can use fast installation script
IMPORTANT: You sholud to run the script under the user where it is installed umee node.

Don't use **sudo** if UMEE-user is not **root** 
```
wget https://raw.githubusercontent.com/shurinov/mon_umee/main/mon_install.sh
chmod +x mon_install.sh
./mon_install.sh
```
It will install telegraf agent, clone project repo and extract your node data as MONIKER, VALOPER ADDR, RPC PORT
You should answer some question about your monitoring service from part **Monitoring server installation**

### Manual installation

Install telegraf
```
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

# make the telegraf user sudo and adm to be able to execute scripts as umee user
sudo adduser telegraf sudo
sudo adduser telegraf adm
sudo -- bash -c 'echo "telegraf ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers'
```
You can check telegram service status:
```
systemctl status telegraf
```
Clone this project repo and copy variable script template
```
git clone https://github.com/shurinov/mon_umee.git
cd mon_umee
cp mon_var_template.sh mon_var.sh
nano mon_var.sh
```

Insert your parameters to **mor_var.sh**:
* full path to umeed binary to COS_BIN_NAME ( check ```which umeed```)
* node PRC port to COS_PORT_RPC ( check in file ```path_to_umee_node_config/config/config.toml```)
* node validator address to COS_VALOPER ( like ```umeevaloper********```)

Save changes in mon_var.sh and enable execution permissions:

```
chmod +x monitoring.sh mon_var.sh
```

Edit telegraf configuration
```
sudo mv /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.orig
sudo nano /etc/telegraf/telegraf.conf
```
Copy to config and paste your server name (for this it is convenient to use the node moniker ):
```
# Global Agent Configuration
[agent]
  hostname = "YOUR_MONIKER/SERVER_NAME" # set this to a name you want to identify your node in the grafana dashboard
  flush_interval = "15s"
  interval = "15s"
# Input Plugins
[[inputs.cpu]]
  percpu = true
  totalcpu = true
  collect_cpu_time = false
  report_active = false
[[inputs.disk]]
  ignore_fs = ["devtmpfs", "devfs"]
[[inputs.io]]
[[inputs.mem]]
[[inputs.net]]
[[inputs.system]]
[[inputs.swap]]
[[inputs.netstat]]
[[inputs.processes]]
[[inputs.kernel]]
[[inputs.diskio]]
# Output Plugin InfluxDB
[[outputs.influxdb]]
  database = "umeemetricsdb"
  urls = [ "MONITORING_SERV_URL:PORT" ] # example http://yourownmonitoringnode:8086
  username = "DB_USERNAME" # your database username
  password = "DB_PASSWORD" # your database user's password
[[inputs.exec]]
  commands = ["sudo su -c UMEE_BIN_NAME -s /bin/bash UMEE_USER"] # change home and username to the useraccount your validator runs at
  interval = "15s"
  timeout = "5s"
  data_format = "influx"
  data_type = "integer""
```

