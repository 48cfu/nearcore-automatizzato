#!/bin/bash

source ~/.profile
network="betanet" # oppure mainnet/testnet
frequency=$((60*60)) # secondi
your_user=48cfu  # nome utente di git
your_personal_access_token=$GIT_PERSONAL_TOKEN

while true; do 
	echo "Checking for updates.."
	diff <(curl -s https://rpc."$network".near.org/status | jq .version.version) <(curl -s http://127.0.0.1:3030/status | jq .version.version)
	if [ $? -ne 0 ]; then
		echo "Nuova versione disponible. Triggering Github Actions..."
		version=$(curl -s https://rpc."$network".near.org/status | jq .version.version)
		curl -X POST https://api.github.com/repos/$your_user/nearcore-automatizzato/dispatches \
			-H 'Accept: application/vnd.github.v3+json' \
			-u $your_user:$your_personal_access_token \
			--data-raw '{"event_type": '$version', "client_payload": {"network": "'$network'"}}'
	else
		echo "Niente da aggiornare."
	fi
	echo "Sleep per $frequency secondi"
	sleep $frequency
done
