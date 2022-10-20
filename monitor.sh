#!/bin/bash
pushd `dirname ${0}` >/dev/null || exit 1

# Get node variables
source ./mon_var.sh
# Set default curl timeout
TO=2

# Get timestamp
now=$(date +%s%N)

# Get umeed version
version=$(${COS_BIN_NAME} version 2>&1)

# fill header
logentry="umee"
if [ -n "${COS_VALOPER}" ]; then logentry=$logentry",valoper=${COS_VALOPER}"; fi

# health is great by default
health=0

if [ -z "$version" ];
then 
    echo "ERROR: can't find UMEE binary">&2 ;
    health=1
    echo $logentry" health=$health $now"
else
    # Get node status
    status=$(curl --connect-timeout ${TO} -s ${NODE_RPC}/status)
    if [ -z "$status" ];
    then
        echo "ERROR: can't connect to UMEE RPC">&2 ;
        health=2
        echo $logentry" health=$health $now"
    else
        # Get block height
        block_height=$(jq -r '.result.sync_info.latest_block_height' <<<$status)
        # Get block time
        latest_block_time=$(jq -r '.result.sync_info.latest_block_time' <<<$status)
        let "time_since_block = $(date +"%s") - $(date -d "$latest_block_time" +"%s")"
        latest_block_time=$(date -d "$latest_block_time" +"%s")
        # check time
        if [ $time_since_block -gt 30 ]; then health=4; fi

        # Get catchup status
        catching_up=$(jq -r '.result.sync_info.catching_up' <<<$status)
        # Get Tendermint voting power
        voting_power=$(jq -r '.result.validator_info.voting_power' <<<$status)
        # Peers count
        peers_num=$(curl --connect-timeout ${TO} -s ${NODE_RPC}/net_info | jq -r '.result.n_peers')
        # Prepare metiric to out
        logentry=$logentry" ver=\"$version\",block_height=$block_height,catching_up=$catching_up,time_since_block=$time_since_block,latest_block_time=$latest_block_time,peers_num=$peers_num,voting_power=$voting_power"
        # Common validator statistic
        # Numbers of active validators
        list_limit=3000
        val_active_numb=$(${COS_BIN_NAME} q staking validators -o json --limit=${list_limit} --node "${NODE_RPC}" |\
        jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r ' .description.moniker' | wc -l)
        logentry="$logentry,val_active_numb=$val_active_numb"

        if [ $MON_MODE == "rpc" ]
        then
            health=100 # Health RPC mode code
        else 
            #
            # Peggo metrics
            #
            # Ethereum node latest block height
            eth_height=$(echo "ibase=16; $(echo $(curl --connect-timeout ${TO} -s -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":83}' ${ETH_NODE_RPC} | jq -r '.result' | cut -c 3-) | tr [:lower:] [:upper:])" | bc)
            if [ -z "${eth_height}" ]; then eth_height=-1; fi
            peggo_metrics="eth_height=$eth_height"

            # Get peggo current valset nonce
            valset_cur_nonce=$(curl --connect-timeout ${TO} -s ${NODE_API}/gravity/v1beta/valset/current | jq -r '.valset.nonce')
            if [ -z "${valset_cur_nonce}" ]; then valset_cur_nonce=-1; fi
            peggo_metrics="$peggo_metrics,valset_cur_nonce=$valset_cur_nonce"

            # Check our bridge address in current valset
            if [ -z $(curl --connect-timeout ${TO} -s ${NODE_API}/gravity/v1beta/valset/current | jq -r '.valset.members[].ethereum_address' | grep ${ETH_BR_ADDR}) ]
            then
                valset_cur_ok=false
            else
                valset_cur_ok=true
            fi
            peggo_metrics="$peggo_metrics,valset_cur_ok=$valset_cur_ok"

            # Get eventnonce
            grav_eventnonce=$(curl --connect-timeout ${TO} -s ${NODE_API}/gravity/v1beta/oracle/eventnonce/${COS_BR_ADDR} | jq -r '.event_nonce')
            if [ -z "${grav_eventnonce}" ]; then grav_eventnonce=-1; fi
            peggo_metrics="$peggo_metrics,grav_eventnonce=$grav_eventnonce"
            logentry="$logentry,$peggo_metrics"

            #
            # PFD metrics
            #
            # Get missed counter
            pfd_miss_cnt=$(curl --connect-timeout ${TO} -s ${NODE_API}/umee/oracle/v1/validators/${COS_VALOPER}/miss | jq -r '.miss_counter')
            if [ -z "${pfd_miss_cnt}" ]; then pfd_miss_cnt=-1; fi
            pfd_metrics="pfd_miss_cnt=$pfd_miss_cnt"
            # Get UMEE price
            pfd_ex_rate_UMEE=$(curl --connect-timeout ${TO} -s ${NODE_API}/umee/oracle/v1/denoms/exchange_rates/ | jq '.exchange_rates[] | select(.denom=="UMEE")' | jq -r '.amount')
            if [ -z "${pfd_ex_rate_UMEE}" ]; then pfd_ex_rate_UMEE=-1; fi
            pfd_metrics="$pfd_metrics,pfd_ex_rate_UMEE=$pfd_ex_rate_UMEE"

            logentry="$logentry,$pfd_metrics"
            #
            # Get our validator metrics
            #
            if [ -n "${COS_VALOPER}" ]
            then
                val_status=$(${COS_BIN_NAME} query staking validator ${COS_VALOPER} --output json --node "${NODE_RPC}")
            fi
            # Parse validator status
            if [ -n "$val_status" ]
            then
                jailed=$(jq -r '.jailed' <<<$val_status)
                # Get all delegated to node tokens num
                delegated=$(jq -r '.tokens' <<<$val_status)
                # Get bond status
                bond=3
                if [ $(jq -r '.status' <<<$val_status) == "BOND_STATUS_UNBONDED" ]; then bond=2; fi
                if [ $(jq -r '.status' <<<$val_status) == "BOND_STATUS_UNBONDING" ]; then bond=1; fi
                if [ $(jq -r '.status' <<<$val_status) == "BOND_STATUS_BONDED" ]; then bond=0; fi
                # Missing blocks number in window
                bl_missed=$(jq -r '.missed_blocks_counter' <<<$($COS_BIN_NAME q slashing signing-info $($COS_BIN_NAME tendermint show-validator) -o json --node "${NODE_RPC}"))
                if [ -z "${bl_missed}" ]; then bl_missed=-1; fi
                # Our validator stake value rank (if not in list assign -1 value)
                val_rank=$(${COS_BIN_NAME} q staking validators -o json --limit=${list_limit} --node "${NODE_RPC}" | \
                jq '.validators[] | select(.status=="BOND_STATUS_BONDED")' | jq -r '.tokens + " - " + .operator_address'  | sort -gr | nl |\
                grep  "${COS_VALOPER}" | awk '{print $1}')
                if [ -z "$val_rank" ]; then val_rank=-1; fi
                logentry="$logentry,jailed=$jailed,delegated=$delegated,bond=$bond,bl_missed=$bl_missed,val_rank=$val_rank"
            else 
                health=3 # validator status problem
            fi
        fi # MON_MODE
        echo "$logentry,health=$health $now"
    fi # umee rpc check
fi # umee binary check
