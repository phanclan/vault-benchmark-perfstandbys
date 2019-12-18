. env.sh
# export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
# export VAULT_TOKEN=$(consul kv get service/vault/root-token)
# export VAULT_TOKEN=${VAULT_TOKEN:-'root'}
green "Enter vault port:"
# export VAULT_PORT=$(read -rs VAULT_PORT)
# export VAULT_PORT=${VAULT_PORT:-10101}
# export VAULT_ADDR=http://127.0.0.1:${VAULT_PORT}
# pe "echo $VAULT_TOKEN"

tput clear
cyan "#------------------------------------------------------------------------------
# Running: $0: ENABLE THE K/V SECRETS ENGINE
#------------------------------------------------------------------------------\n"

cyan 'Before Vault can "do stuff", a secrets engine must be enabled.
Engines are enabled at a specified path.\n'

white "COMMAND: vault secrets enable -path=<name of secrets> kv"
echo
green "#------------------------------------------------------------------------------
# Enable a KV V2 Secret engine at the path 'labsecrets'
#------------------------------------------------------------------------------\n"
export KV_PATH=labsecrets
pe "vault secrets enable -path=${KV_PATH} -version=${KV_VERSION} kv"

# kv-blog for test scripts
vault secrets enable -path=kv-blog -version=2 kv > /dev/null 2>&1

green "List out the enabled secrets engines."
pe "vault secrets list"
p "Press Enter to continue"

tput clear
# Show the two methods of how to engage with Vault: CLI or API
cyan "#-------------------------------------------------------------------------------
# ENGAGE WITH VAULT VIA CLI
#-------------------------------------------------------------------------------\n"

cyan 'Two different methods to write a secret to Vault: CLI and API

To run commands via CLI you must authenticate to Vault first via: '
echo

white "vault login <method> \n"
cyan "where method could be a token, or username or other enabled authorization mechanism."
echo

# cyan 'We can create, read, update, and delete secrets.'
# We will also look at how to version and roll back secrets.
echo

green '#--- Create a new secret with a "key of apikey" and 
"value of master-api-key-111111" within the "${KV_PATH}" path:'
echo
white 'CLI COMMAND: vault kv put <secrets engine>/<secret name> <key>=<value>'

pe "vault kv put ${KV_PATH}/apikeys/googlemain apikey=master-api-key-111111"

echo
green '#--- To read it back:'
pe "vault kv get ${KV_PATH}/apikeys/googlemain"
p "Press Enter to continue"

tput clear
cyan '#-------------------------------------------------------------------------------
# ENGAGE WITH VAULT USING API
#-------------------------------------------------------------------------------\n'

cyan 'We can also interact with Vault via the HTTP API.

Vault API uses standard HTTP verbs: GET, PUT, POST, LIST, UPDATE etc...'
echo 
white "API COMMAND: curl -H \"X-Vault-Token: <vault token>\" -X POST -d '{\"<key>\": \"<value>\"}' \\
    \$VAULT_ADDR/v1/<secrets engine>/<location>/<secret> | jq"
echo
echo

green "Create a new secret called 'gvoiceapikey' with a value of 'PassTheHash!:'"
cat << EOF
curl -s
    -H "X-Vault-Token: $VAULT_TOKEN" 
    -H "Content-Type: application/json" 
    -X POST 
    -d '{ "data": { "gvoiceapikey": "PassTheHash!" } }' 
    ${VAULT_ADDR}/v1/${KV_PATH}/data/apikeys/googlevoice
EOF
p "Press Enter to continue"

curl -s \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    -d '{ "data": { "gvoiceapikey": "PassTheHash!" } }' \
    http://127.0.0.1:${VAULT_PORT}/v1/${KV_PATH}/data/apikeys/googlevoice | jq 

echo
p "Press Enter to continue"

tput clear
green '#--- Read the secret:'
echo
cat << EOF
curl -s
    -H "X-Vault-Token: $VAULT_TOKEN" 
    -X GET 
    ${VAULT_ADDR}/v1/${KV_PATH}/data/apikeys/googlevoice | jq .data
EOF
p "Press Enter to continue"

curl -s \
    -H "X-Vault-Token: $VAULT_TOKEN" \
    -X GET \
    ${VAULT_ADDR}/v1/${KV_PATH}/data/apikeys/googlevoice | jq .data
p "Press Enter to continue"

# Run through several CLI commands // also sets up the environment for later use
tput clear
cyan "#--------------------------------------------------------------
# ADDITIONAL EXAMPLES OF INTERACTION WITH VAULT VIA CLI
#--------------------------------------------------------------"
echo
cyan "Some quick examples of the Vault CLI in action: \n"
echo ""
green '#--- POST SECRET: MULTIPLE FIELDS'
echo ""
pe 'vault kv put labsecrets/webapp username="beaker" password="meepmeepmeep"'
p "Press Enter to continue"

echo ""
green "#--- RETRIEVE SECRET:"
echo ""
pe "vault kv get labsecrets/webapp"
echo ""
p "Press Enter to continue"

tput clear
green "#--- RETRIEVE SECRET BY FIELD:"
echo ""
pe "vault kv get -field=password labsecrets/webapp"
p "Press Enter to continue"

# NOT AS INTERESTING TO SHOW
# echo ""
# green "PULL VIA JSON IF NEEDED:"
# echo ""
# pe "vault kv get -format=json labsecrets/webapp | jq -r .data.data.password"

# p "Press Enter to continue"

tput clear
green "#--- LOAD SECRET VIA FILE PAYLOAD: vault kv put <secrets engine>/<location> @<name of file>.json"
echo
echo
yellow "TIP: Loading via payload file in CLI is recommended, or ensure history is not being recorded."
echo ""
green "EXAMPLE PAYLOAD:"
pe "cat ./vault/files/data.json"
echo ""
pe "vault kv put labsecrets/labinfo @./vault/files/data.json"

green "#--- Insert some additional secrets for use later in demo / hide action"
vault kv put labsecrets/lab_keypad code="12345" >/dev/null
vault kv put labsecrets/lab_room room="A113" >/dev/null


p "Press Enter to continue"

# tput clear
# # Run through several API
# cyan "#--------------------------------------------------------------
# # ADDITIONAL EXAMPLES OF INTERACTION WITH VAULT VIA API
# #--------------------------------------------------------------"
# echo
# cyan "Some quick examples of the Vault API in action: \n"
# echo ""
# green "#--- WRITE A SECRET VIA API:\n"
# white "COMMAND: curl -s -H "X-Vault-Token: \$VAULT_TOKEN" -X POST -d '{"\<key\>": "\<value\>"}' \\
#     \$VAULT_ADDR/v1/<secrets engine>/<location>/<secret> | jq"
# echo ""
# cat << EOF
# curl -s -H "X-Vault-Token: $VAULT_TOKEN" \\
#     -X POST \\
#     -d '{"data":{"gmapapikey": "where-am-i-??????"}}' \\
#     $VAULT_ADDR/v1/labsecrets/apikeys/googlemaps | jq
# EOF
# p "Press Enter to continue"

# curl -s -H "X-Vault-Token: $VAULT_TOKEN" \
#     -X POST \
#     -d '{"data":{"gmapapikey": "where-am-i-??????"}}' \
#     $VAULT_ADDR/v1/labsecrets/data/apikeys/googlemaps | jq

# echo ""
# p "Press Enter to continue"

# tput clear
# green "#--- READ A SECRET VIA API:"
# echo ""
# white "curl -H "X-Vault-Token: \$VAULT_TOKEN" $VAULT_ADDR/v1/labsecrets/data/apikeys/googlemaps | jq "
# p "Press Enter to continue"

# curl -sH "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/labsecrets/data/apikeys/googlemaps | jq

# echo ""
# p "Press Enter to continue"

# tput clear
# green "#-- READ A SECRET VIA API AND PARSE JSON:"
# echo ""
# white "curl -s -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/labsecrets/data/apikeys/googlemaps | jq  -r .data.gmapapikey"
# p

# curl -s -H "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/labsecrets/data/apikeys/googlemaps | jq -r .data.data.gmapapikey
# echo ""

# p "Press Enter to continue"

# tput clear
# # Show how you can list secrets
# cyan "#--------------------------------------------------------------
# # LIST SECRETS LOADED INTO K/V ENGINE SO FAR
# #--------------------------------------------------------------\n"

# cyan "To show the secrets that are posted under the particular secrets engine"
# echo ""
# white "COMMAND: vault kv list labsecrets"
# echo ""
# pe "vault kv list labsecrets" 

echo ""
white "This concludes the static secrets engine component of the demo."
p "Press Enter to continue"
