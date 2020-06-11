#!/bin/bash
set -e
shopt -s expand_aliases
. env.sh

cyan "Running: $0: Vault Agent Templates"
echo

cyan "
#------------------------------------------------------------------------------
# Step 0: Pre-requisites
#------------------------------------------------------------------------------"
echo ""

cyan "
#------------------------------------------------------------------------------
# Step 1: Start Vault and log in
#------------------------------------------------------------------------------"
echo
# green "Start Vault dev"
# pe "vault server -dev -dev-root-token-id=$VAULT_TOKEN -dev-listen-address=0.0.0.0:8200 > /tmp/vault.log 2>&1 &"

# green "Login with root token"
# pe "vault login root"

# green "Enable audit device, so you can examine logs later"
# pe "vault audit enable file file_path=/tmp/audit.log log_raw=true"

#==> Begin old section
# green "Create a policy configuration file"
# tee /tmp/myapp.hcl <<EOF
# path "secret/myapp/*" {
#     capabilities = ["read", "list"]
# }
# EOF

# green "Create a policy named 'myapp'"
# vault policy write myapp /tmp/myapp.hcl

# green "Write some secrets in 'secret/app/config' path"
# vault kv put secret/myapp/config \
#     ttl='30s' \
#     username='appuser' \
#     password='suP3rsec(et!' \"

#==> End old section

#-------------------------------------------------------------------------------
# Step 2: Configure Vault Server for Agent Auto-Auth
#-------------------------------------------------------------------------------"
echo
cyan "Vault Agent runs on the client side to automate leases and tokens lifecycle management."
echo

green "#==> Enable a new KV (version 2) secrets engine at kvAgentDemo:"
vault secrets enable -path=kvAgentDemo -version=2 kv || true

green "#==> Write and verify the new KV:"
vault kv put kvAgentDemo/legacy_app_creds_01 username=legacyUser password=supersecret
# vault kv get kvAgentDemo/legacy_app_creds_01

green "#==> Create policy demo-policy from demo-policy.hcl file."
yellow "This policy gives permissions on kvAgentDemo/*, see file for details."
tee ./tmp/demo-policy.hcl <<EOF
# demo-policy.hcl
path "kvAgentDemo/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
vault policy write demo-policy ./tmp/demo-policy.hcl
p "Press Enter to continue"

#==> Begin old section
# green ""
# pe '
# tee /tmp/token_update.hcl <<"EOF"
# # Permits token creation
# path "auth/token/create" {
#   capabilities = ["update"]
# }
# EOF
# '

# green 'Create a policy named, "token_update"'
# pe "vault policy write token_update /tmp/token_update.hcl"
#==> End old section

green "#==> Enable approle auth method on the Vault server."
vault auth enable approle || true

green '#==> Create approle role. Name: "agentdemo". Policy attached: demo-policy.'
vault write auth/approle/role/agentdemo policies="demo-policy"

green "#==> Get role ID for new approle role"
vault read -field=role_id auth/approle/role/agentdemo/role-id > ./tmp/roleid

#==> Begin old section
# green 'Create approle role. Named "apps" with token_update policy attached.'
# pe 'vault write auth/approle/role/apps policies="token_update"'

# green 'Generate a role ID and stores it in a file named, "roleID.txt".'
# pe "vault read -format=json auth/approle/role/apps/role-id \
#         | jq  -r '.data.role_id' > /tmp/roleID.txt"
#==> End old section

yellow "The approle auth method allows machines or apps
to authenticate with Vault using Vault-defined roles.
The generated roleID is equivalent to username."
echo

green '#==> Create a secret ID and store it in a "secretID" file.'
# pe "vault write -f -format=json auth/approle/role/apps/secret-id \
#         | jq -r '.data.secret_id' > /tmp/secretid.txt"
pe "vault write -f -field=secret_id auth/approle/role/agentdemo/secret-id > ./tmp/secretid"

yellow "The generated secretID is equivalent to a password.

Refer to the AppRole Pull Authentication guide to learn more.
https://learn.hashicorp.com/vault/identity-access-management/iam-authentication
"
p "Press Enter to continue"

cyan "
#------------------------------------------------------------------------------
# Step 2: Vault Agent Auto-Auth
#------------------------------------------------------------------------------"
echo
echo "#==> Set version of Vault to install"
export VAULT_VERSION=1.4.0

green "#==> Create cloud-init file for VM."
tee ./tmp/multipass-init.yml <<EOF
package_update: true
runcmd:
  - set -x
  - echo apt-get update
  - apt-get install -qq unzip
  - echo "#==> Create directories"
  - mkdir -p /run/mydir
  - mkdir -p /run/tmp
  - echo "#==> Install Vault"
  - curl -s -o /run/mydir/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip && unzip -qqo -d /usr/local/bin/ /run/mydir/vault.zip
EOF
echo "More info on cloud-init: https://cloudinit.readthedocs.io/en/latest/topics/examples.html"

echo "#==> Create VM. Name agent-demo. Point to cloud-init file."
# multipass delete agent-demo -p

multipass launch -n agent-demo -c 1 -m 512M -d 5G \
  --cloud-init ./tmp/multipass-init.yml || true
echo "#==> Reboot so multipass mount would work"
# rebooting from the VM causes problems, so rebooting with multipass
multipass restart agent-demo

green "#==> Create the template.ctmpl file. This file defines the output that will be rendered."
tee ./tmp/template.ctmpl <<EOF
{{/* Read the secret at the path below */}}
{{ with secret "kvAgentDemo/legacy_app_creds_01" }}
 Username: {{ .Data.data.username }}
 Password: {{ .Data.data.password }}
Create TS: {{ .Data.metadata.created_time }}
  Version: {{ .Data.metadata.version }}

All raw metadata: {{ .Data }}
{{ end }}
EOF

green "#==> Run vault agent"

#vault agent -config=../vault/files/agent-demo.hcl

multipass mount ./tmp agent-demo:/run/tmp || true
cp ../vault/files/agent-demo.hcl ./tmp/agent-demo.hcl
multipass exec agent-demo -- sh -c 'echo "192.168.64.10 vault.hashi.local" | sudo tee -a /etc/hosts'
multipass exec agent-demo -- vault agent -config=/run/tmp/agent-demo.hcl

# multipass shell agent-demo

# Sample agent file here: https://github.com/mikegreen/vault-agent-demo/blob/master/agent-demo.hcl
p "Press Enter to continue"


cyan "
#------------------------------------------------------------------------------
# Challenge
#------------------------------------------------------------------------------"

cyan "What happens if your data gets updated?"
green "#==> Update the secret:"
vault kv patch kvAgentDemo/legacy_app_creds_01 \
  password=supersecret3

# vault kv patch secret/customers/acme contact_email="jenn@acme.com"
# Takes about 4 minutes
p "Press Enter to continue"

cyan "
##########################################################################################
# Step 3: Template Configuration
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
VAULT_TOKEN=$(cat /tmp/sink_file_unwrapped_2.txt) vault token create -ttl=30s -explicit-max-ttl=2m

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


# https://www.vaultproject.io/docs/agent/template





















