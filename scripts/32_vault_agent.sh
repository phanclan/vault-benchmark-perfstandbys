#!/bin/bash
# set -e

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. demo-magic.sh -d -p -w ${DEMO_WAIT}

cyan "Running: $0: Creating Policies"
echo

cyan "
##########################################################################################
# Step 0: Pre-requisites
##########################################################################################"
echo

cyan ""
green '

'

cyan "
##########################################################################################
# Step 1: Start Vault and log in
##########################################################################################"
echo
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

green "Start Vault dev"
pe "vault server -dev -dev-root-token-id=$VAULT_TOKEN -dev-listen-address=0.0.0.0:8200 > /tmp/vault.log 2>&1 &"

green "Login with root token"
pe "vault login root"

green "Enable audit device, so you can examine logs later"
pe "vault audit enable file file_path=/tmp/audit.log log_raw=true"

green "Create a policy configuration file"
pe 'tee /tmp/myapp.hcl <<EOF
path "secret/myapp/*" {
    capabilities = ["read", "list"]
}
EOF'

green "Create a policy named 'myapp'"
pe 'vault policy write myapp /tmp/myapp.hcl'

green "Write some secrets in 'secret/app/config' path"
pe "vault kv put secret/myapp/config \
    ttl='30s' \
    username='appuser' \
    password='suP3rsec(et!'"

cyan "
##########################################################################################
# Step 2: Vault Agent Auto-Auth
##########################################################################################"
echo
cyan "Vault Agent runs on the client side to automate leases and tokens lifecycle management."
echo
green "Enable the approle auth method on the Vault server."
pe "vault auth enable approle"

green ""
pe '
tee /tmp/token_update.hcl <<"EOF"
# Permits token creation
path "auth/token/create" {
  capabilities = ["update"]
}
EOF
'

green 'Create a policy named, "token_update"'
pe "vault policy write token_update /tmp/token_update.hcl"

green 'Create a role named "apps" with token_update policy attached.'
pe 'vault write auth/approle/role/apps policies="token_update"'

green 'Generate a role ID and stores it in a file named, "roleID.txt".'
pe "vault read -format=json auth/approle/role/apps/role-id \
        | jq  -r '.data.role_id' > /tmp/roleID.txt"

yellow "The approle auth method allows machines or apps 
to authenticate with Vault using Vault-defined roles. 
The generated roleID is equivalent to username."
echo

green 'generate a secret ID and stores it in the "secretID" file.'
pe "vault write -f -format=json auth/approle/role/apps/secret-id \
        | jq -r '.data.secret_id' > /tmp/secretID.txt"

yellow "The generated secretID is equivalent to a password.

Refer to the AppRole Pull Authentication guide to learn more.
https://learn.hashicorp.com/vault/identity-access-management/iam-authentication
"

cyan "
##########################################################################################
# Step 3: Vault Agent Configuration
##########################################################################################"
echo

green 'Create the Vault Agent configuration file, agent-config.hcl.'
pe '
tee /tmp/agent-config.hcl <<"EOF"
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
           path = "approleToken"
       }
   }
}

vault {
   address = "http://127.0.0.1:8200"
}
EOF
'

yellow "The auto_auth block points to the approle auth method, 
and the acquired token gets stored in approleToken file which is the sink location."
echo

green 'Execute the following command to start the Vault Agent with debug logs.'
pe 'vault agent -config=/tmp/agent-config.hcl -log-level=debug'

green 'The agent log should include the following messages:
...
[INFO]  sink.file: creating file sink
[INFO]  sink.file: file sink configured: path=approleToken
[INFO]  auth.handler: starting auth handler
[INFO]  auth.handler: authenticating
[INFO]  sink.server: starting sink server
[INFO]  auth.handler: authentication successful, sending token to sinks
[INFO]  auth.handler: starting renewal process
[INFO]  sink.file: token written: path=approleToken
...'

yellow 'The acquired client token is now stored in the approleToken file. 
Your applications can read the token from approleToken and use it to invoke the Vault API.'
echo

green 'Click the + next to the opened Terminal, and select Open New Terminal to open another terminal.'
echo

green 'Execute the following command to verify the token information.'
pe "export VAULT_ADDR='http://127.0.0.1:8200'"
pe "vault token lookup $(cat approleToken)"

green 'Verify that the token has the token_update policy attached.'

green "Key                  Value
---                  -----
...
display_name         approle
entity_id            f06b5047-6174-eda5-8530-d067c77e26bc
expire_time          2019-05-19T01:32:26.451100637Z
explicit_max_ttl     0s
id                   s.YKo3MLA6dSshKgeStGuIxIsJ
...
meta                 map[role_name:apps]
...
path                 auth/approle/login
policies             [default token_update] <---
..."

green 'You should be able to create a token using this token (permitted by the token_update policy).'
pe "VAULT_TOKEN=$(cat approleToken) vault token create"

cyan "
##########################################################################################
# Step 4: Vault Agent Caching
##########################################################################################"
echo

cyan 'To enable Vault Agent Caching, the agent configuration file must define cache and listener stanzas. 
The listener stanza specifies the proxy address which Vault Agent listens. 
All the requests will be made through this address and forwarded to the Vault server.'

green 'Examine the Vault Agent configuration file, agent-config-caching.hcl.'

pe '
tee /tmp/agent-config-caching.hcl <<EOF
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
           path = "approleToken"
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
EOF'

yellow 'In this example, the agent listens to port 8007.'

green 'Execute the following command to start the Vault Agent with debug logs.'

pe 'vault agent -config=agent-config-caching.hcl -log-level=debug'

green 'In the Terminal 3, set the VAULT_AGENT_ADDR environment variable.'
pe 'export VAULT_AGENT_ADDR="http://127.0.0.1:8007"'

green 'Execute the following command to create a short-lived token and see how agent manages its lifecycle:'
pe "VAULT_TOKEN=$(cat approleToken) vault token create -ttl=30s -explicit-max-ttl=2m"

yellow 'For the purpose of demonstration, the generated token has only 30 seconds before it expires. Also, its max TTL is 2 minutes; therefore, it cannot be renewed beyond 2 minutes from its creation.

Key                  Value
---                  -----
token                s.qaPOodPTUdtbj5REak2ICuyg
token_accessor       Bov810fwIPlp48bENCuW8xv9
token_duration       30s
token_renewable      true
token_policies       ["token_update" "default"]
identity_policies    []
policies             ["token_update" "default"]'

green 'Examine the agent log in Terminal 2. The log should include the following messages:

...
[INFO]  cache: received request: path=/v1/auth/token/create method=POST
[DEBUG] cache.leasecache: forwarding request: path=/v1/auth/token/create method=POST
[INFO]  cache.apiproxy: forwarding request: path=/v1/auth/token/create method=POST
[DEBUG] cache.leasecache: processing auth response: path=/v1/auth/token/create method=POST
[DEBUG] cache.leasecache: setting parent context: path=/v1/auth/token/create method=POST
[DEBUG] cache.leasecache: storing response into the cache: path=/v1/auth/token/create method=POST
[DEBUG] cache.leasecache: initiating renewal: path=/v1/auth/token/create method=POST
[DEBUG] cache.leasecache: secret renewed: path=/v1/auth/token/create
'

yellow 'The request was first sent to VAULT_AGENT_ADDR (agent proxy) 
and then forwarded to the Vault server (VAULT_ADDR). 
You should find an entry in the log indicating that the returned token was stored in the cache.'

green 'Re-run the command and observe the returned token value.'
pe "VAULT_TOKEN=$(cat approleToken) vault token create -ttl=30s -explicit-max-ttl=2m"

yellow "It should be the same token."

green "The agent log indicates the following:

...
[INFO]  cache: received request: path=/v1/auth/token/create method=POST
[DEBUG] cache.leasecache: returning cached response: path=/v1/auth/token/create

Continue watching the agent log to see how it manages the token's lifecycle.

...
[DEBUG] cache.leasecache: secret renewed: path=/v1/auth/token/create
[DEBUG] cache.leasecache: secret renewed: path=/v1/auth/token/create
[DEBUG] cache.leasecache: secret renewed: path=/v1/auth/token/create
[DEBUG] cache.leasecache: secret renewed: path=/v1/auth/token/create
[DEBUG] cache.leasecache: secret renewed: path=/v1/auth/token/create

Vault Agent renews the token before its TTL until the token reaches its maximum TTL (2 minutes). 
Once the token reaches its max TTL, agent fails to renew it because the Vault server revokes it.

[DEBUG] cache.leasecache: renewal halted; evicting from cache: path=/v1/auth/token/create
[DEBUG] cache.leasecache: evicting index from cache: id=1f9d3e6d037d18f1e91b70be9918f95009433bf585252134de6a41a187e873ee path=/v1/auth/token/create method=POST

When the token renewal failed, the agent automatically evicts the token from the cache since it's a stale cache."


cyan "
##########################################################################################
# Step 5: Evict Cached Leases
##########################################################################################"
echo

cyan "While agent observes requests and evicts cached entries automatically, 
you can trigger a cache eviction by invoking the /agent/v1/cache-clear endpoint."
echo
green "To evict a lease, invoke the /agent/v1/cache-clear endpoint along with the ID of the lease you wish to evict."

pe "curl -X POST -d '{"type": "lease", "value": "<lease_id>"}' \
       $VAULT_AGENT_ADDR/agent/v1/cache-clear"

If a situation requires you to clear all cached tokens and leases (e.g. reset after a number of testing), set the type to all.

curl -X POST -d '{"type": "all"}' $VAULT_AGENT_ADDR/agent/v1/cache-clear

In the agent log, you find the following:

[DEBUG] cache.leasecache: received cache-clear request: type=all namespace= value=
[DEBUG] cache.leasecache: canceling base context
[DEBUG] cache.leasecache: successfully cleared matching cache entries
























