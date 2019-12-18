#!/bin/bash

PATH=`pwd`/bin:$PATH
if [ -f demo_env.sh ]; then
    . ./demo_env.sh
fi

. env.sh

CRED_NUMS="0 1 2"

export VAULT_TOKEN=${VAULT_ROOT_TOKEN}
export MYSQL_HOST=${DB_HOSTNAME}
export MYSQL_TCP_PORT=${DB_PORT}

pe "vault token create -policy sakila-backend -ttl 1h -format=json > /tmp/sakila-backend.token"
pe "SAKILA_BACKEND_TOKEN=`jq -r .auth.client_token /tmp/sakila-backend.token`"

# Clean up all pre-existing credentials. We won't show this during the talk,
# because we cover it at the end, but we want to clear out now so we only
# see the credentials we're talking about in MySQL
vault lease revoke -prefix database/creds/sakila-admin 2>&1 >/dev/null
vault lease revoke -prefix database/creds/sakila-backend 2>&1 >/dev/null


# clear
cyan "Let's generate three credentials files. We'll do it with 'consul-template',"
cyan "much like in the previous step."
echo
for i in ${CRED_NUMS}; do
    VAULT_TOKEN=$SAKILA_BACKEND_TOKEN consul-template \
	-vault-addr=$VAULT_ADDR \
	-template "007-sakila-backend.my.cnf.tmpl:/tmp/sakila-backend-${i}.my.cnf" \
	-once -vault-renew-token
done
ls -l /tmp/sakila-backend-*.my.cnf
read

# clear
cyan "Connect to the MySQL server. Confirm we see three unique usernames:"
echo
green "SELECT user FROM user WHERE user LIKE 'v-token%';"
echo
mysql --defaults-file=/tmp/.my-admin.cnf mysql -e "select user from user where user like 'v-token%';"
read

clear
cyan "#--- Verify we can use each of those files:"
for i in ${CRED_NUMS}; do
    echo "Credential sakila-backend-${i}.my.cnf:"
    mysql --defaults-file=/tmp/sakila-backend-${i}.my.cnf -e "show grants;"
    echo
done
read

clear
cyan "Now let's say you start a rolling deployment of a new backend. You push out"
cyan "a canary instance and your monitoring detects you accidentally left DEBUG"
cyan "turned on, so it logged your database credentials to your logging setup."
cyan "With dynamic credentials, revoking a single credential is easy."
echo
cyan "Let's say it's the instance with sakila-backend-2.my.cnf. We logged the"
cyan "lease ID in the generated configuration file:"
echo 
pe "cat /tmp/sakila-backend-2.my.cnf"
# read

# clear
cyan "And we can revoke *just* that lease."
echo
LEASE_ID=`grep "# Lease:" /tmp/sakila-backend-2.my.cnf | cut -d ' ' -f 3`
green vault lease revoke $LEASE_ID
pe "vault lease revoke $LEASE_ID"
echo
read

clear
cyan "Let's see what happened: "
# read
green "Try to access the database."
for i in ${CRED_NUMS}; do
    echo "Credential sakila-backend-${i}.my.cnf:"
    mysql --defaults-file=/tmp/sakila-backend-${i}.my.cnf -e "show grants;"
    echo
done
echo
green "Note that sakila-backend-2.my.cnf is no longer usable."
read

clear
cyan "#--- Let's verify that the user doesn't even exist on the database any more."
echo
green "Here's the username for the deleted user."
pe "grep "user=" /tmp/sakila-backend-2.my.cnf"
echo
green "SELECT user FROM user WHERE user LIKE 'v-token%';"
mysql --defaults-file=/tmp/.my-admin.cnf mysql -e "select user from user where user like 'v-token%';"
green "User is no longer there"
read

clear
cyan "Now let's pretend your security team has found an exploit the backend code"
cyan "and needs to do an emergency revocation of *all* backend database"
cyan "credentials:"
echo
green vault lease revoke -prefix database/creds/sakila-backend
pe "vault lease revoke -prefix database/creds/sakila-backend"
read

clear
cyan "#--- Again, let's see what happened: "
read
for i in ${CRED_NUMS}; do
    echo "Credential sakila-backend-${i}.my.cnf:"
    mysql --defaults-file=/tmp/sakila-backend-${i}.my.cnf -e "show grants;"
    echo
done
echo
green "Note that none of them are usable now."
read

# clear
cyan "And let's verify that none of the users exist in the database:"
echo
pe "grep "user=" /tmp/sakila-backend-*.my.cnf"
echo
green "SELECT user FROM user WHERE user LIKE 'v-token%';"
mysql --defaults-file=/tmp/.my-admin.cnf mysql -e "select user from user where user like 'v-token%';" --quick
read
