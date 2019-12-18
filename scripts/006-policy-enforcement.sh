#!/bin/bash

# PATH=`pwd`/bin:$PATH
if [ -f demo_env.sh ]; then
    . ./demo_env.sh
fi

. env.sh

export VAULT_TOKEN=${VAULT_ROOT_TOKEN}

clear
cyan "Generate some tokens with the sakila-admin policy"
cyan "and see what happens when we try to use them to get access to"
cyan "the sakila-backend database role"
echo
echo
green "vault token create -policy sakila-admin"
pe "vault token create -policy sakila-admin -format=json > sakila-admin.token"
pe "SAKILA_ADMIN_TOKEN=`jq -r .auth.client_token sakila-admin.token`"
pe "VAULT_TOKEN=$SAKILA_ADMIN_TOKEN vault read auth/token/lookup-self"

read
clear
cyan "#--- Try to fetch sakila-backend database role credentials"
echo
echo
echo "vault read database/creds/sakila-backend"
pe "VAULT_TOKEN=$SAKILA_ADMIN_TOKEN vault read database/creds/sakila-backend -format=json"


read
clear
cyan "Same idea, just the other way around."
cyan "Attempt to access the sakila-admin role with only sakila-backend rights"
# cyan "role when I only have sakila-backend rights"
echo
echo
green "Create token with sakila-backend rights."
echo
echo "vault token create -policy sakila-backend"
pe "vault token create -policy sakila-backend -format=json > sakila-backend.token"
pe "SAKILA_BACKEND_TOKEN=`jq -r .auth.client_token sakila-backend.token`"
pe "VAULT_TOKEN=$SAKILA_BACKEND_TOKEN vault read auth/token/lookup-self"

read
clear
cyan "Try to fetch sakila-admin database role credentials"
echo
echo "vault read database/creds/sakila-admin"
pe "VAULT_TOKEN=$SAKILA_BACKEND_TOKEN vault read database/creds/sakila-admin -format=json"
echo
echo
