. env.sh
# This is from Vault 202 class.

## CONFIG LOCAL ENV
echo "[*] Config local environment..."
# alias vault='docker-compose exec vault vault "$@"'
export VAULT_ADDR=http://127.0.0.1:8200

# export VAULT_TOKEN=$(grep 'Initial Root Token:' ./_data/keys.txt | awk '{print substr($NF, 1, length($NF)-1)}')
export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/key.txt | awk '{print $NF}')
export VAULT_TOKEN=${VAULT_TOKEN:-'root'}

## AUTH
green "[*] Auth..."
# vault auth -address=${VAULT_ADDR} ${VAULT_TOKEN}
pe "vault login ${VAULT_TOKEN}"

green "For the purpose of education, enable raw data log"
pe "vault audit enable file file_path=/vault/logs/${HOSTNAME}-audit-1.log log_raw=true"


# Create some initial policies
# vault policy write base - <<"EOT"
# path "secret/data/training_*" {
#    capabilities = ["create", "read"]
# }
# EOT

# vault policy write test - <<"EOT"
# path "secret/data/test" {
#    capabilities = [ "create", "read", "update", "delete" ]
# }
# EOT

# vault policy write team-qa - <<"EOT"
# path "secret/data/team/qa" {
#    capabilities = [ "create", "read", "update", "delete" ]
# }
# EOT

# vault policy write team-eng - <<"EOT"
# path "secret/data/team/eng" {
#    capabilities = [ "create", "read", "update", "delete" ]
# }
# EOT



