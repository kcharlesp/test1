#!/bin/sh

# Default to "data".
DATADIR="${DATADIR:-/terra/.terra/data}"
MONIKER="${MONIKER:-docker-node}"
ENABLE_LCD="${ENABLE_LCD:-true}"
MINIMUM_GAS_PRICES=${MINIMUM_GAS_PRICES-0.01133uluna,0.15uusd,0.104938usdr,169.77ukrw,428.571umnt,0.125ueur,0.98ucny,16.37ujpy,0.11ugbp,10.88uinr,0.19ucad,0.14uchf,0.19uaud,0.2usgd,4.62uthb,1.25usek,1.25unok,0.9udkk,2180.0uidr,7.6uphp,1.17uhkd}
SNAPSHOT_NAME="${SNAPSHOT_NAME}"
SNAPSHOT_BASE_URL="${SNAPSHOT_BASE_URL:-https://getsfo.quicksync.io}"

# Terra net feature (must be managed only by terra-operator)
IS_LOCALNET="${IS_LOCALNET:-false}"

# continue terra node if .terra is already specified (in case of halt before)
if [ -d "~/.terra" ]; then
  terrad start $TERRAD_STARTUP_PARAMETERS &
  wait
  exit 0
fi

# if IS_LOCALNET is false, then init chain
if [ "$IS_LOCALNET" = "false" ] ; then
  # Moniker will be updated by entrypoint.
  terrad init --chain-id $CHAINID $MONIKER
else
  # this is PVC mounted on k8s
  # each node will have env HOSTNAME that tells which pod name it is in kube
  NODE_POSITION=$(printenv HOSTNAME | rev | cut -d "-" -f 1 | rev)
  cp -r ~/mytestnet/node$NODE_POSITION/.terra ~/.terra
fi

# Backup for templating
cp ~/.terra/config/config.toml ~/config.toml
cp ~/.terra/config/app.toml ~/app.toml

# auto config seed
if [ "$IS_LOCALNET" = "true" ] ; then
  gentxs=$(find ~/mytestnet/gentxs -name "*.json")
  set -- $gentxs

  seed_string=""
  while [ -n "$1" ]; do
    current=$(basename $1 | cut -d '.' -f 1 | sed 's/[^0-9]*//g')

    if [ "$current" = "$NODE_POSITION" ] ; then
      shift
      continue
    fi

    seed=$(cat $1 | jq -r ".body.memo" | cut -d "@" -f 1)
    # get ip of seed
    base_hostname=$(printenv HOSTNAME | sed 's/-[0-9]*$//')
    pod_name="$base_hostname-$current"
    echo $pod_name
    ip=$(dig +short $pod_name.$SERVICE_NAME.default.svc.cluster.local)
    if [ ! -z "$ip" ]; then
      seed_string="$seed@$ip:26656,$seed_string"
    fi
    shift
  done

  seed_string=${seed_string::-1}

  # replace seed string
  gawk -v new_peers="\"$seed_string\"" -i inplace '/^persistent_peers /{gsub(/"([^"]+)"/,new_peers)}1' ~/.terra/config/config.toml
fi

# First sed gets the app.toml moved into place.
# app.toml updates
sed 's/minimum-gas-prices = "0uluna"/minimum-gas-prices = "'"$MINIMUM_GAS_PRICES"'"/g' ~/app.toml > ~/.terra/config/app.toml

# Needed to use awk to replace this multiline string.
if [ "$ENABLE_LCD" = true ] ; then
  gawk -i inplace '{if (f==0 && /enable = false/) {sub(/false/, "true"); f=1}}1' ~/.terra/config/app.toml
  gawk -i inplace '{if (f==0 && /swagger = false/) {sub(/false/, "true"); f=1}}1' ~/.terra/config/app.toml
fi

# config.toml updates
sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/g' ~/.terra/config/config.toml

if [ "$IS_LOCALNET" = "true" ] ; then
  terrad start $TERRAD_STARTUP_PARAMETERS &
  wait
  exit 0
fi

if [ "$CHAINID" = "columbus-5" ] ; then wget -O ~/.terra/config/genesis.json https://columbus-genesis.s3.ap-northeast-1.amazonaws.com/columbus-5-genesis.json; fi; \
if [ "$CHAINID" = "columbus-5" ] ; then wget -O ~/.terra/config/addrbook.json https://networks.mcontrol.ml/columbus/addrbook.json; fi; \
if [ "$CHAINID" = "rebel-1" ]    ; then wget -O ~/.terra/config/genesis.json https://raw.githubusercontent.com/terra-rebels/classic-testnet/master/rebel-1/genesis.json; fi; \
if [ "$CHAINID" = "rebel-1" ]    ; then wget -O ~/.terra/config/addrbook.json https://raw.githubusercontent.com/terra-rebels/classic-testnet/master/rebel-1/addrbook.json; fi; \
if [ "$CHAINID" = "rebel-2" ]    ; then wget -O ~/.terra/config/genesis.json https://raw.githubusercontent.com/terra-rebels/classic-testnet/master/rebel-2/genesis.json; fi; \
if [ "$CHAINID" = "rebel-2" ]    ; then wget -O ~/.terra/config/addrbook.json https://raw.githubusercontent.com/terra-rebels/classic-testnet/master/rebel-2/addrbook.json; fi;

if [ "$CHAINID" = "columbus-5" ] && [[ ! -z "$SNAPSHOT_NAME" ]] ; then 
  # Download the snapshot if data directory is empty.
  res=$(find "$DATADIR" -name "*.db")
  if [ "$res" ]; then
      echo "data directory is NOT empty, skipping quicksync"
  else
      echo "starting snapshot download"
      mkdir -p $DATADIR
      cd $DATADIR
      FILENAME="$SNAPSHOT_NAME"

      # Download
      aria2c -x5 $SNAPSHOT_BASE_URL/$FILENAME
      # Extract
      lz4 -d $FILENAME | tar xf -

      # # cleanup
      rm $FILENAME
  fi
fi

# check if it is new network
if [ "$NEW_NETWORK" = "true" ] ; then
  # add new gentx
  sh /test-node-setup.sh
fi

terrad start $TERRAD_STARTUP_PARAMETERS &

if [ "$NEW_NETWORK" = "false" ] ; then
  #Wait for Terrad to catch up
  while true
  do
    if ! (( $(echo $(terrad status) | awk -F '"catching_up":|},"ValidatorInfo"' '{print $2}') ));
    then
      break
    fi
    sleep 1
  done

  if [ ! -z "$VALIDATOR_AUTO_CONFIG" ] && [ "$VALIDATOR_AUTO_CONFIG" = "1" ]; then
    if [ ! -z "$VALIDATOR_KEYNAME" ] && [ ! -z "$VALIDATOR_MNENOMIC" ] && [ ! -z "$VALIDATOR_PASSPHRASE" ] ; then
      terrad keys add $VALIDATOR_KEYNAME --recover > ~/.terra/keys.log 2>&1 << EOF
$VALIDATOR_MNENOMIC
$VALIDATOR_PASSPHRASE
$VALIDATOR_PASSPHRASE
EOF
    fi

    if [ ! -z "$VALIDATOR_AMOUNT" ] && [ ! -z "$MONIKER" ] && [ ! -z "$VALIDATOR_PASSPHRASE" ] && [ ! -z "$VALIDATOR_KEYNAME" ] && [ ! -z "$VALIDATOR_KEYNAME" ] && [ ! -z "$VALIDATOR_COMMISSION_RATE" ] && [ ! -z "$VALIDATOR_COMMISSION_RATE_MAX" ]  && [ ! -z "$VALIDATOR_COMMISSION_RATE_MAX_CHANGE" ]  && [ ! -z "$VALIDATOR_MIN_SELF_DELEGATION" ] ; then
      terrad tx staking create-validator --amount=$VALIDATOR_AMOUNT --pubkey=$(terrad tendermint show-validator) --moniker="$MONIKER" --chain-id=$CHAINID --from=$VALIDATOR_KEYNAME --commission-rate="$VALIDATOR_COMMISSION_RATE" --commission-max-rate="$VALIDATOR_COMMISSION_RATE_MAX" --commission-max-change-rate="$VALIDATOR_COMMISSION_RATE_MAX_CHANGE" --min-self-delegation="$VALIDATOR_MIN_SELF_DELEGATION" --gas=$VALIDATOR_GAS --gas-adjustment=$VALIDATOR_GAS_ADJUSTMENT --fees=$VALIDATOR_FEES > ~/.terra/validator.log 2>&1 << EOF
$VALIDATOR_PASSPHRASE
y
EOF
    fi
  fi
fi

wait