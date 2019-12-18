#!/usr/bin/env bash
set -e
set -x
echo "==> Vault (client)"

# echo "--> Fetching"
# install_from_url "vault" "${vault_url}"

echo "--> Creating workspace"
sudo mkdir -p /workstation/vault
git clone https://github.com/hashicorp/demo-vault-202.git /workstation/vault202

sudo mkdir -p /workstation/vault/raft-node2
sudo mkdir -p /workstation/vault/raft-node3

echo "--> Writing profile"
sudo tee /etc/profile.d/vault.sh > /dev/null <<"EOF"
alias v="vault"
alias vault="vault"
export VAULT_ADDR="http://127.0.0.1:8200"
EOF
source /etc/profile.d/vault.sh

sudo tee /etc/systemd/system/vault.service > /dev/null <<"EOF"
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target

[Service]
Environment=GOMAXPROCS=8
Environment=VAULT_DEV_ROOT_TOKEN_ID=root
Restart=on-failure
ExecStart=/usr/local/bin/vault server -dev -dev-listen-address=0.0.0.0:8200
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF
# sudo systemctl enable vault
# sudo systemctl start vault
sleep 2

#echo "--> Seeding Vault with a generic secret"
#VAULT_TOKEN=root vault kv put secret/training value='Hello!'

echo "--> Creating workspace"
# TODO: Clone https://github.com/hashicorp/demo-vault-beginner.git
# sudo mkdir -p /workstation
# git clone https://github.com/hashicorp/demo-vault-beginner.git /workstation/vault
sudo mkdir -pm 0777 /workstation/{vault101,vault102}

echo "--> Adding files to workstation"
sudo tee /workstation/vault10{1,2}/readonly.sql > /dev/null <<"EOF"
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
REVOKE ALL ON SCHEMA public FROM public, "{{name}}";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";
EOF

sudo tee /workstation/vault101/rotation.sql > /dev/null <<"EOF"
ALTER USER "{{name}}" WITH PASSWORD '{{password}}';
EOF

sudo tee /workstation/vault101/config.yml.tpl > /dev/null <<"EOF"
---
{{- with secret "database/creds/readonly" }}
username: "{{ .Data.username }}"
password: "{{ .Data.password }}"
database: "myapp"
{{- end }}
EOF

sudo tee /workstation/vault101/app.sh > /dev/null <<"EOF"
#!/usr/bin/env bash

cat <<EOT
My connection info is:

  username: "$${DATABASE_CREDS_READONLY_USERNAME}"
  password: "$${DATABASE_CREDS_READONLY_PASSWORD}"
  database: "my-app"
EOT
EOF
sudo chmod +x /workstation/vault101/app.sh

sudo tee /workstation/vault101/data.json > /dev/null <<"EOF"
{
  "organization": "hashicorp",
  "region": "US-West",
  "zip_code": "94105"
}
EOF


sudo tee /workstation/vault101/setup-approle.sh > /dev/null <<"EOF"
vault login root

# Create db_readonly policy
vault policy write db_readonly - <<POL
path "database/creds/readonly" {
  capabilities = [ "read" ]
}

path "/sys/leases/renew" {
  capabilities = [ "update" ]
}

path "auth/token/create" {
  capabilities = ["update"]
}
POL

# Setup approle
vault auth enable approle
vault write auth/approle/role/apps policies="db_readonly"
echo $(vault read -format=json auth/approle/role/apps/role-id | jq  -r '.data.role_id') > roleID
echo $(vault write -f -format=json auth/approle/role/apps/secret-id | jq -r '.data.secret_id') > secretID
EOF
sudo chmod +x /workstation/vault101/setup-approle.sh


sudo tee /workstation/vault101/agent-config.hcl > /dev/null <<"EOF"
exit_after_auth = false
pid_file = "./pidfile"

auto_auth {
   method "approle" {
       mount_path = "auth/approle"
       config = {
           role_id_file_path = "roleID"
           secret_id_file_path = "secretID"
           remove_secret_id_file_after_reading = false
       }
   }

   sink "file" {
       config = {
           path = "/workstation/vault101/approleToken"
       }
   }
}

cache {
   use_auto_auth_token = true
}

listener "tcp" {
   address = "127.0.0.1:8007"
   tls_disable = true
}

vault {
   address = "http://127.0.0.1:8200"
}
EOF

sudo tee /workstation/vault102/setup-approle.sh > /dev/null <<"EOF"
vault login $(grep 'Initial Root Token:' key.txt | awk '{print $NF}')

# Create db_readonly policy
vault policy write db_readonly - <<POL
path "database/creds/readonly" {
  capabilities = [ "read" ]
}

path "/sys/leases/renew" {
  capabilities = [ "update" ]
}

path "auth/token/create" {
  capabilities = ["update"]
}
POL

# Enable database secrets engine
vault secrets enable database
vault write database/config/postgresql plugin_name=postgresql-database-plugin allowed_roles=readonly connection_url=postgresql://postgres@localhost/myapp
vault write database/roles/readonly db_name=postgresql creation_statements=@readonly.sql default_ttl=1h max_ttl=24h

# Setup approle
vault auth enable approle
vault write auth/approle/role/apps policies="db_readonly"
echo $(vault read -format=json auth/approle/role/apps/role-id | jq  -r '.data.role_id') > roleID
echo $(vault write -f -format=json auth/approle/role/apps/secret-id | jq -r '.data.secret_id') > secretID
EOF
sudo chmod +x /workstation/vault102/setup-approle.sh

sudo tee /workstation/vault102/agent-config.hcl > /dev/null <<"EOF"
exit_after_auth = false
pid_file = "./pidfile"

auto_auth {
   method "approle" {
       mount_path = "auth/approle"
       config = {
           role_id_file_path = "roleID"
           secret_id_file_path = "secretID"
           remove_secret_id_file_after_reading = false
       }
   }

   sink "file" {
       config = {
           path = "/workstation/vault102/approleToken"
       }
   }
}

cache {
   use_auto_auth_token = true
}

listener "tcp" {
   address = "127.0.0.1:8007"
   tls_disable = true
}

vault {
   address = "http://127.0.0.1:8200"
}
EOF

sudo tee /workstation/vault102/test.hcl > /dev/null <<"EOF"
path "kv/data/test" {
   capabilities = [ "create", "read", "update", "delete" ]
}
EOF

sudo tee /workstation/vault102/base.hcl > /dev/null <<"EOF"
path "kv/data/training_*" {
   capabilities = ["create", "read"]
}

path "kv/data/+/apikey" {
   capabilities = ["create", "read", "update", "delete"]
}
EOF

sudo tee /workstation/vault102/team-qa.hcl > /dev/null <<"EOF"
path "kv/data/team/qa" {
   capabilities = [ "create", "read", "update", "delete" ]
}
EOF

sudo tee /workstation/vault102/team-eng.hcl > /dev/null <<"EOF"
path "secret/data/team/eng" {
   capabilities = [ "create", "read", "update", "delete" ]
}
EOF

sudo tee /workstation/vault102/config.hcl > /dev/null <<"EOF"
disable_mlock = true
ui = true

# Use the file storage - this will write encrypted data to disk.
storage "file" {
  path = "/workstation/vault102/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
EOF


sudo tee /workstation/vault102/config-autounseal.hcl > /dev/null <<"EOF"
disable_mlock = true
ui=true

storage "file" {
  path = "/workstation/vault102/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

seal "transit" {
  address = "http://"
  token = ""
  disable_renewal = "false"
  key_name = "autounseal"
  mount_path = "transit/"
  tls_skip_verify = "true"
}
EOF

sudo tee /workstation/vault102/config-autounseal-2.hcl > /dev/null <<"EOF"
disable_mlock = true
ui=true

storage "file" {
  path = "/workstation/vault102/data-2"
}

listener "tcp" {
  address     = "0.0.0.0:8100"
  tls_disable = 1
}

seal "transit" {
  address = "http://127.0.0.1:8200"
  token = ""
  disable_renewal = "false"
  key_name = "autounseal"
  mount_path = "transit/"
  tls_skip_verify = "true"
}
EOF

sudo tee /workstation/vault102/autounseal.hcl > /dev/null <<"EOF"
path "transit/encrypt/autounseal" {
   capabilities = [ "update" ]
}

path "transit/decrypt/autounseal" {
   capabilities = [ "update" ]
}
EOF


#sudo systemctl stop consul

echo "--> Installing completions"
# sudo su vagrant \
#   -c 'vault -autocomplete-install'


echo "--> Changing ownership"
sudo chown -R vagrant:vagrant "/workstation/vault101"
sudo chown -R vagrant:vagrant "/workstation/vault102"
# sudo usermod -a -G sudo vagrant

echo "==> Vault is done!"
