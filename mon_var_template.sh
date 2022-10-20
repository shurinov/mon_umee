#UMEE monitoring variables template
MON_MODE=rpc   # use for RPC/sentry nodes
#MON_MODE=val   # use for Validator nodes
COS_BIN_NAME=insert_path_to_umee_binary # example: /root/go/bin/umeed or /home/user/go/bin/umeed
COS_DENOM=uumee  # umee denominator. don't change
COS_PORT_RPC=26657 # insert node RPC port here if it's not default (26657)
COS_PORT_API=1317  # insert node API port here if it's not default (1317)
NODE_RPC="http://localhost:${COS_PORT_RPC}"
NODE_API="http://localhost:${COS_PORT_API}"
COS_VALOPER=     # validator address, example: umeevaloper1234545636767376535673
COS_WALADDR=     # validator wallet address, example: umee123454563676***376535673
COS_BR_ADDR=     # Peggo bridge address, example: umee123454563676***376535673
ETH_BR_ADDR=     # Peggo bridge etherium wallet address, example 0x12345**890ABCD
ETH_NODE_RPC=    # Path to your etherium node RPC, example http://localhost:8545 or http://12.34.56.78:8545
