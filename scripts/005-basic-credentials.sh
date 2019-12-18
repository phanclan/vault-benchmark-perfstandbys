#!/bin/bash

# PATH=`pwd`/bin:$PATH
if [ -f demo_env.sh ]; then
    . ./demo_env.sh
fi
. env.sh

# export VAULT_TOKEN=${VAULT_ROOT_TOKEN}
export VAULT_ROOT_TOKEN=$VAULT_TOKEN
export MYSQL_HOST=${DB_HOSTNAME}
export MYSQL_TCP_PORT=${DB_PORT}

clear
cyan "#--- Generate some tokens with the 'sakila-admin' policy"
echo
echo
green "vault token create -policy sakila-admin"
pe "vault token create -policy sakila-admin -ttl=1h -format=json > /tmp/sakila-admin.token"
pe "SAKILA_ADMIN_TOKEN=`jq -r .auth.client_token /tmp/sakila-admin.token`"
pe "VAULT_TOKEN=$SAKILA_ADMIN_TOKEN vault read auth/token/lookup-self"

# read
# clear
cyan "#--- Use the sakila-admin token to fetch some database credentials"
echo
echo
green "vault read database/creds/sakila-admin"
pe "VAULT_TOKEN=$SAKILA_ADMIN_TOKEN vault read database/creds/sakila-admin -format=json > /tmp/sakila-admin.creds"
pe "jq . /tmp/sakila-admin.creds"

# read
clear

cyan "#--- Let's try those credentials out"
pe "SAKILA_DB_USER=`jq -r .data.username /tmp/sakila-admin.creds`"
pe "SAKILA_DB_PASS=`jq -r .data.password /tmp/sakila-admin.creds`"

green "#--- Try to log in and run 'show grants'."
set -x
mysql -u"$SAKILA_DB_USER" -p"$SAKILA_DB_PASS" sakila -e "show grants;show tables;"
set +x
echo
echo
read
cyan "#--- Revoke those credentials and see what happens"
green "When token is revoked so is db account."
echo
echo "vault token revoke -self"
pe "VAULT_TOKEN=$SAKILA_ADMIN_TOKEN vault token revoke -self"
# read
echo
echo
set -x
mysql -u"$SAKILA_DB_USER" -p"$SAKILA_DB_PASS" sakila -e "show grants;"
set +x
echo
echo
read

clear
cyan "#--- Do the same for the sakila-backend policy"
green "This time, however, let's make direct use of the Vault RESTful API"
echo
echo
cat <<EOF | tee /tmp/sakila-backend.request.json
{
  "policies": ["sakila-backend"]
}
EOF
read

clear
echo
echo
cat <<EOF
curl -s 
  --header "X-Vault-Token: ${VAULT_ROOT_TOKEN}" 
  --request POST 
  --data @/tmp/sakila-backend.request.json 
  ${VAULT_ADDR}/v1/auth/token/create > /tmp/sakila-backend.token
EOF

curl -s \
  --header "X-Vault-Token: ${VAULT_ROOT_TOKEN}" \
  --request POST \
  --data @/tmp/sakila-backend.request.json \
  ${VAULT_ADDR}/v1/auth/token/create > /tmp/sakila-backend.token
read

# clear
pe "jq . /tmp/sakila-backend.token"
pe "SAKILA_BACKEND_TOKEN=`jq -r .auth.client_token /tmp/sakila-backend.token`"

# read
clear
cyan "#--- Use the sakila-backend token to fetch some database credentials"
echo
echo
echo 'curl -s \
  --header "X-Vault-Token: $SAKILA_BACKEND_TOKEN" \
  ${VAULT_ADDR}/v1/database/creds/sakila-backend > /tmp/sakila-backend.creds'
curl -s \
  --header "X-Vault-Token: $SAKILA_BACKEND_TOKEN" \
  ${VAULT_ADDR}/v1/database/creds/sakila-backend > /tmp/sakila-backend.creds

read
# clear
pe "jq . /tmp/sakila-backend.creds"


read
clear
cyan "#--- Try those credentials out"
pe "SAKILA_DB_USER=`jq -r .data.username /tmp/sakila-backend.creds`"
pe "SAKILA_DB_PASS=`jq -r .data.password /tmp/sakila-backend.creds`"
set -x
mysql -u"$SAKILA_DB_USER" -p"$SAKILA_DB_PASS" sakila -e "show grants; show tables;"
set +x
echo
echo
read
cyan "#--- Revoke those credentials and see what happens"
echo "vault token revoke -self"
pe "VAULT_TOKEN=$SAKILA_BACKEND_TOKEN vault token revoke -self"
# read
echo
echo
green "Try to log in and run 'show grants'. When token is revoked so is db account."
set -x
mysql -u"$SAKILA_DB_USER" -p"$SAKILA_DB_PASS" sakila -e "show grants;"
set +x
