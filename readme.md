# Umee node monitoring tool

Used toolset:
* [Telegraf](https://www.influxdata.com/time-series-platform/telegraf/)
* [InfluxDB](https://www.influxdata.com/products/influxdb/)
* [Grafana](https://grafana.com/)

The project was inspired by Solana community monitoring from [Stakeconomy](https://github.com/stakeconomy/solanamonitoring) 

## Installation 

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
You should answer some question about your monitoring service.
