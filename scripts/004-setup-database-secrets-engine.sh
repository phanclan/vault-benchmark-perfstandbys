#!/bin/bash

# PATH=`pwd`/bin:$PATH
if [ -f demo_env.sh ]; then
    . ./demo_env.sh
fi

. env.sh

# export VAULT_TOKEN=${VAULT_ROOT_TOKEN}

clear
green "Enabling the Vault database secret engine"

# echo "vault secrets enable database"
pe "vault secrets enable database"

echo
echo
# read
# clear

green "Configuring a database connection"
cat <<EOT
vault write database/config/sakila 
    plugin_name=mysql-database-plugin 
    connection_url="${DB_USERNAME}:${DB_PASSWORD}@tcp(${DB_HOSTNAME}:${DB_PORT})/" 
    username="${DB_USERNAME}" 
    password="${DB_PASSWORD}" 
    allowed_roles="sakila-admin,sakila-backend"
EOT
vault write database/config/sakila \
    plugin_name=mysql-database-plugin \
    connection_url="${DB_USERNAME}:${DB_PASSWORD}@tcp(${DB_HOSTNAME}:${DB_PORT})/" \
    username="${DB_USERNAME}" \
    password="${DB_PASSWORD}" \
    allowed_roles="sakila-admin,sakila-backend"

echo
echo
read
#clear

green "Creating sakila-admin role"
cat << EOF
vault write database/roles/sakila-admin 
    db_name=sakila 
    default_ttl=1h 
    max_ttl=4h 
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL PRIVILEGES ON sakila.* TO '{{name}}'@'%';"
EOF
vault write database/roles/sakila-admin \
    db_name=sakila \
    default_ttl=1h \
    max_ttl=4h \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL PRIVILEGES ON sakila.* TO '{{name}}'@'%';"

echo
echo
echo "CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';"
echo "GRANT ALL PRIVILEGES ON sakila.* TO '{{name}}'@'%';"
read
#clear

green "Creating sakila-backend role"
cat << EOF
vault write database/roles/sakila-backend 
    db_name=sakila 
    default_ttl=8h 
    max_ttl=240h 
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT,INSERT,DELETE,UPDATE ON sakila.* TO '{{name}}'@'%';"
EOF
vault write database/roles/sakila-backend \
    db_name=sakila \
    default_ttl=8h \
    max_ttl=240h \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT,INSERT,DELETE,UPDATE ON sakila.* TO '{{name}}'@'%';"

echo
echo
echo "CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';"
echo "GRANT SELECT,INSERT,DELETE,UPDATE ON sakila.* TO '{{name}}'@'%';"
read
clear

cyan "Create sakila admin and backend policies."
echo
green "Creating sakila-admin policy"
cat <<EOF | tee /tmp/sakila-admin-policy.hcl
path "database/creds/sakila-admin" {
  capabilities = ["read"]
}

path "database/roles" {
  capabilities = ["list"]
}

path "database/roles/sakila-admin" {
  capabilities = ["read"]
}
EOF

cat <<EOF | tee /tmp/mysql.hcl
path “database/*” {
 capabilities = [“read”]
}
EOF


echo
echo

# green "vault policy write sakila-admin /tmp/sakila-admin-policy.hcl"
pe "vault policy write sakila-admin /tmp/sakila-admin-policy.hcl"

echo
echo
# read
#clear

green "Creating sakila-backend policy"
cat <<EOF | tee /tmp/sakila-backend-policy.hcl
path "database/creds/sakila-backend" {
  capabilities = ["read"]
}

path "database/roles" {
  capabilities = ["list"]
}

path "database/roles/sakila-backend" {
  capabilities = ["read"]
}
EOF
echo
echo

# echo vault policy write sakila-backend /tmp/sakila-backend-policy.hcl
pe "vault policy write sakila-backend /tmp/sakila-backend-policy.hcl"

echo
echo
# read
#clear
