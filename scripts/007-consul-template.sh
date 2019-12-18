#!/bin/bash

PATH=`pwd`/bin:$PATH
if [ -f demo_env.sh ]; then
    . ./demo_env.sh
fi

. env.sh
export VAULT_TOKEN=${VAULT_ROOT_TOKEN}
pe "vault token create -policy sakila-backend -ttl 1h -format=json | tee sakila-backend.token"
pe "SAKILA_BACKEND_TOKEN=`jq -r .auth.client_token sakila-backend.token`"

# clear
cyan "Let's use a tool called 'consul-template' to automate retrieving"
cyan "secrets from Vault and rendering them in a way that existing"
cyan "applications can easily consume in their configuration files."
echo
echo
read

# clear
cyan "Consul-template renders a template, like this one:"
echo
echo
green "cat 007-sakila-backend.my.cnf.tmpl"
cat 007-sakila-backend.my.cnf.tmpl
read

clear
cyan "Run it once to generate a MySQL default file 'sakila-backend-0.my.cnf'"
echo
echo 'VAULT_TOKEN=$SAKILA_BACKEND_TOKEN consul-template \
    -vault-addr=$VAULT_ADDR \
    -template "007-sakila-backend.my.cnf.tmpl:sakila-backend-0.my.cnf" \
    -once -vault-renew-token'
VAULT_TOKEN=$SAKILA_BACKEND_TOKEN consul-template \
    -vault-addr=$VAULT_ADDR \
    -template "007-sakila-backend.my.cnf.tmpl:sakila-backend-0.my.cnf" \
    -once -vault-renew-token  2>/dev/null
read

# clear
cyan "Look in the file. It looks like a regular MySQL defaults file"
echo
pe "cat sakila-backend-0.my.cnf"

