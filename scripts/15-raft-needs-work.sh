


tee /tmp/config-vault1.hcl <<EOF
storage "inmem" {}
listener "tcp" {
  address = "127.0.0.1:8200"
  tls_disable = true
}
EOF

VAULT_API_ADDR=http://127.0.0.1:8200 vault server -log-level=trace -config $TEST_HOME/config-vault1.hcl > $TEST_HOME/vault1.log 2>&1 &

sleep 5s

INIT_RESPONSE=$(vault_1 operator init -format=json -key-shares 1 -key-threshold 1)

UNSEAL_KEY=$(echo $INIT_RESPONSE | jq -r .unseal_keys_b64[0])
ROOT_TOKEN=$(echo $INIT_RESPONSE | jq -r .root_token)

echo $UNSEAL_KEY
echo $ROOT_TOKEN

vault operator unseal $UNSEAL_KEY
vault login $ROOT_TOKEN

green "Enable the transit secrets engine."
vault secrets enable transit
green "Create a key named unseal_key"
vault write -f transit/keys/unseal_key

cyan "Initialize Vault Node1"

rm -rf /tmp/vault-raft/
mkdir -pm 0755 /tmp/vault-raft
vault server -log-level=trace -config /tmp/config-vault2.hcl > /tmp/vault2.log 2>&1 &
INIT_RESPONSE2=$(vault operator init -format=json -key-shares 1 -key-threshold 1)
# pe "vault operator init -format=json -key-shares 1 -key-threshold 1 > /tmp/vault-out.txt"
UNSEAL_KEY2=$(echo $INIT_RESPONSE2 | jq -r .unseal_keys_b64[0])
ROOT_TOKEN2=$(echo $INIT_RESPONSE2 | jq -r .root_token)
echo $UNSEAL_KEY2
echo $ROOT_TOKEN2

sleep 15s
vault login $ROOT_TOKEN2

vault secrets enable -path=kv kv-v2

sleep 2s
vault kv put kv/apikey webapp=ABB39KKPTWOR832JGNLS02
vault kv get kv/apikey

vault write sys/license text=<YOUR_LICENSE_STRING>

# NODE 3
rm -rf /tmp/vault-raft2/
mkdir -pm 0755 /tmp/vault-raft2
vault server -log-level=trace -config /tmp/config-vault3.hcl > /tmp/vault3.log 2>&1 &
vault operator raft join http://192.168.50.101:8200

# NODE 4
rm -rf /tmp/vault-raft/
mkdir -pm 0755 /tmp/vault-raft
vault server -log-level=trace -config /tmp/config-vault.hcl > /tmp/vault.log 2>&1 &
vault operator raft join http://192.168.50.101:8200

########################################################################
# ON NODE 1
########################################################################

cyan "Start the server"
