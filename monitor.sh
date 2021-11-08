#!/bin/bash
pushd `dirname ${0}` >/dev/null || exit 1

# Get node variables
source ./mon_var.sh
# Get timestamp
now=$(date +%s%N)

# Get umeed version
version=$(${COS_BIN_NAME} version 2>&1)

# Get node status
status=$(curl -s localhost:$COS_PORT_RPC/status)
# Get block height
block_height=$(jq -r '.result.sync_info.latest_block_height' <<<$status)
# Get block time
latest_block_time=$(jq -r '.result.sync_info.latest_block_time' <<<$status)
let "time_since_block = $(date +"%s") - $(date -d "$latest_block_time" +"%s")"
latest_block_time=$(date -d "$latest_block_time" +"%s")

# Get catchup status
catching_up=$(jq -r '.result.sync_info.catching_up' <<<$status)

# Get Tendermint votiong power
voting_power=$(jq -r '.result.validator_info.voting_power' <<<$status)
# Missing blocks number in window (in UMEE slashing window size 100 blocks)
bl_missed=$(jq -r '.missed_blocks_counter' <<<$($COS_BIN_NAME q slashing signing-info $($COS_BIN_NAME tendermint show-validator) -o json))
# Peers count
peers_num=$(curl -s localhost:${COS_PORT_RPC}/net_info | jq -r '.result.peers[].node_info | [.id, .moniker] | @csv' | wc -l)

# Prepare metiric to out
logentry="umee,valoper=${COS_VALOPER} ver=\"$version\",block_height=$block_height,catching_up=$catching_up,time_since_block=$time_since_block,\
latest_block_time=$latest_block_time,peers_num=$peers_num,voting_power=$voting_power,bl_missed=$bl_missed"

#
# Get validator status
val_status=$(${COS_BIN_NAME} query staking validator ${COS_VALOPER} --output json --node "tcp://localhost:${COS_PORT_RPC}")

if [ -n "$val_status" ]
then
	jailed=$(jq -r '.jailed' <<<$val_status)
	# Get all delegated to node tokens num
	delegated=$(jq -r '.tokens' <<<$val_status)
	# Get bonded status
	bonded=false
	if [ $(jq -r '.status' <<<$val_status) == "BOND_STATUS_BONDED"  ]
	then
		bonded=true
	fi
	# Get validator statistic
	list_limit=3000
	# Numbers of active validators
	val_active_numb=$(${COS_BIN_NAME} q staking validators -o json --limit=${list_limit} --node "tcp://localhost:${COS_PORT_RPC}" | \
	jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r ' .description.moniker' | wc -l)

	# Our stake value rank 
	val_rank=$(${COS_BIN_NAME} q staking validators -o json --limit=${list_limit} --node "tcp://localhost:${COS_PORT_RPC}" | \
	jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r ' .operator_address'  | sort -gr | nl |\
	grep  "${COS_VALOPER}" | awk '{print $1}')

	logentry=$logentry",jailed=$jailed,delegated=$delegated,bonded=$bonded,val_active_numb=$val_active_numb,val_rank=$val_rank"
fi

echo $logentry" $now"