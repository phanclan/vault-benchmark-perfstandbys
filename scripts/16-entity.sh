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
green "List all existing policies:"
vault policy list

green "Create a new user in userpass auth method:
	username: bob
	password: training
	policy: test
"
vault write auth/userpass/users/bob password="training" policies="test"

green "Read the test policy to review:"
pe "vault policy read test"

green "Create another user in userpass backend:
	username: bsmith
	password: training
	policy: team-qa
"
pe 'vault write auth/userpass/users/bsmith password="training" policies="team-qa"'

green "Read the team-qa policy to review:"
pe "vault policy read test"

green 'Execute the following command to discover the mount accessor for the userpass auth method:
'
pe 'vault auth list'
yellow 'In the output, locate the Accessor value for userpass:'

green 'Save the accessor value for userpass in a file named accessor.txt 
by executing the following command.
'
pe "vault auth list -format=json | jq -r '.["userpass/"].accessor' > accessor.txt"

cyan 'create a new entity named, "bob-smith" and save its entity ID in entity_id.txt for later use.
'
pe 'vault write -format=json identity/entity name="bob-smith" policies="base" \
     metadata=organization="ACME Inc." metadata=team="QA" \
     | jq -r ".data.id" > entity_id.txt'
green 'Notice that the metadata are passed in metadata=<key>=<value> format. 
In the above command, the entity has organization and team as its metadata.

For convenience, the above command used jq to parse the resulting JSON output, 
retrieved the entity ID, and saved it in a file (entity_id.txt). 
Therefore, you did not see the actual response. The command returns the entity ID as follow:

Key        Value
---        -----
aliases    <nil>
id         631256b1-8523-9838-5501-d0a1e2cdad9c

The id is the entity ID.'

cyan '
##########################################################################################
# create an internal group named, engineers. Its member is bob-smith entity
##########################################################################################'
echo

cyan 'First, review the team-eng policy:'
	vault policy read team-eng

cyan 'Create an internal group named engineers. 
Add bob-smith entity as a group member.
Assign the team-eng policy to the group.
For later use, parse the JSON output and 
save the generated group ID in a file named, group_id.txt.'
pe 'vault write -format=json identity/group name="engineers" \
    policies="team-eng" \
    member_entity_ids=$(cat entity_id.txt) \
    metadata=team="Engineering" metadata=region="North America" \
    | jq -r ".data.id" > group_id.txt'

green 'List the existing groups by its name'
pe 'vault list identity/group/name'

green 'List the existing groups by IDs'
pe 'vault list identity/group/id'

green 'Read the details of the group: engineers'
pe 'vault read identity/group/id/$(cat group_id.txt)'

cyan '
##########################################################################################
# Test the Group
##########################################################################################'
echo

cyan 'Test to understand how a token inherits 
the capabilities from its associating group.
'

green 'Login as bsmith with userpass auth method:'
pe 'vault login -method=userpass username="bsmith" password="training"'

cyan 'Test to see if the token has an access to the following paths:
	 1. secret/data/training_test
	 2. secret/data/team/qa
	 3. secret/data/team/eng
	 4. secret/data/test'
pe 'vault token capabilities secret/data/training_test'
pe 'vault token capabilities secret/data/team/qa'
pe 'vault token capabilities secret/data/team/eng'
pe 'vault token capabilities secret/data/test'
yellow 'Last test should fail'

green 'When you are done testing, log back in with the root token.'
pe "vault login $(grep 'Initial Root Token:' key.txt | awk '{print $NF}')"















cyan "
##########################################################################################
# Step 1: Enable GCP Dynamic Secrets
##########################################################################################"
echo
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root

green "Start Vault dev"
pe "vault server -dev -dev-root-token-id=$VAULT_TOKEN -dev-listen-address=0.0.0.0:8200 > /tmp/vault.log 2>&1 &"
pe "vault login root"

green "Enable audit device, so you can examine logs later"
pe "vault audit enable file file_path=/tmp/audit.log log_raw=true"

green "Enable GCP Dynamic Secrets on Vault"
pe "vault secrets enable -path=gcp gcp"

# green "Tune the default lease for the AWS secrets engine to 2 minutes."
# pe "vault secrets tune -default-lease-ttl=2m gcp/"

cyan "Configure the credentials that Vault uses to communicate with GCP to generate the IAM credentials:"
echo
green 'Replace “CRED_FILE.json” with yours. ttl determines life of credentials.'
pe "vault write gcp/config credentials=@../CRED_FILE.json \
ttl=180 max_ttl=3600"

green 'Create binding configuration.'
pe 'tee /tmp/mybindings.hcl <<EOF
      resource "//cloudresourcemanager.googleapis.com/projects/pphan-test-app-dev" {
        roles = ["roles/editor"]
      }
EOF'

cyan 'Configure a GCP role set that associates resources to roles. 
When users generate credentials, they are generated against this role.'
echo

pe 'vault write gcp/roleset/key-role-set \
    project="pphan-test-app-dev" \
    secret_type="service_account_key" \
    bindings=@/tmp/mybindings.hcl'

pe 'export GCP_IAM_ACCOUNT=$(vault read gcp/roleset/key-role-set -format=json | jq -r .data.service_account_email)'

green "Confirm"
pe "gcloud iam service-accounts list"
p

cyan "
##########################################################################################
# Step 2: Usage
##########################################################################################
"
green 'Show current keys for email vault<key-role-set>-* in GCP IAM.'
pe 'gcloud iam service-accounts keys list --iam-account=$GCP_IAM_ACCOUNT'

cyan 'Generate a new credential by reading from the "/key" endpoint with the name of the role:'
pe "vault read gcp/key/key-role-set -format=json > /tmp/key-role-set1.txt"
pe "cat /tmp/key-role-set1.txt | jq -r"
pe 'gcloud iam service-accounts keys list --iam-account=$GCP_IAM_ACCOUNT'

cyan 'Generate a new credential by reading from the "/key" endpoint with the name of the role:'
pe 'curl -H "X-Vault-Token: $VAULT_TOKEN" http://127.0.0.1:8200/v1/gcp/key/key-role-set | jq'

yellow 'Note the lease_id. You will need that value to revoke the credentials.'
echo
green 'Confirm keys for email vault<key-role-set>-* is created in GCP IAM.'
pe 'gcloud iam service-accounts keys list --iam-account=$GCP_IAM_ACCOUNT'
echo

cyan "
##########################################################################################
# Step 3: Revoking the secret
##########################################################################################
"

cyan 'What if these credentials were leaked? We can revoke the credentials.'
pe "export GCP_LEASE_ID=$(jq -r .lease_id < /tmp/key-role-set1.txt)"
pe "vault lease revoke $GCP_LEASE_ID"

yellow "The GCP Service account key is no longer there"
pe 'gcloud iam service-accounts keys list --iam-account=$GCP_IAM_ACCOUNT'
echo
cyan 'What if all my credentials for a role were leaked? Revoke with a prefix.'
pe "vault lease revoke -prefix gcp/key/key-role-set"
pe 'gcloud iam service-accounts keys list --iam-account=$GCP_IAM_ACCOUNT'


green "Create lease"
pe 'curl -H "X-Vault-Token: $VAULT_TOKEN" http://127.0.0.1:8200/v1/gcp/key/key-role-set | jq "." > /tmp/key-role-set2.txt'
pe 'export LEASE_ID=$(jq -r ".lease_id" < /tmp/key-role-set2.txt)'

green "List leases"
pe 'curl -H "X-Vault-Token:$VAULT_TOKEN" -X LIST http://127.0.0.1:8200/v1/sys/leases/lookup/gcp/key/key-role-set | jq ".data.keys" '

green "Renew leases"
pe 'curl -H "X-Vault-Token:$VAULT_TOKEN" -X PUT http://127.0.0.1:8200/v1/sys/leases/renew/$LEASE_ID | jq "."'

green "Revoke leases"
pe 'curl -H "X-Vault-Token:$VAULT_TOKEN" -X PUT http://127.0.0.1:8200/v1/sys/leases/revoke/$LEASE_ID | jq "."'


cyan "
##########################################################################################
# Step 4: Clean Up - Remove role set
##########################################################################################
"
green "Remove the service account. This doesn't get removed when keys expire."
pe 'vault delete gcp/roleset/key-role-set'
# pe 'curl -X DELETE -H "X-Vault-Token: $VAULT_TOKEN" http://127.0.0.1:8200/v1/gcp/roleset/key-role-set'
pe 'gcloud iam service-accounts list'