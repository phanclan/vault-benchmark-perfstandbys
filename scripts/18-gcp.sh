#!/bin/bash
# set -e

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. demo-magic.sh -d -p -w ${DEMO_WAIT}

tput clear
cyan "##########################################################################################
# Running: $0: Enable GCP Dynamic Secrets
##########################################################################################\n"
echo

cyan "#-------------------------------------------------------------------------------
# Step 0: Pre-requisites
#-------------------------------------------------------------------------------\n"
echo

green "Enable cloud resource manager API
https://console.developers.google.com/apis/api/cloudresourcemanager.googleapis.com/overview?project=449803287135"

cyan "Configure our GCP account to use secrets."
green '
Go to Google Cloud Console: https://console.cloud.google.com/
Go to IAM > Service Account.   
Click Create Service Account. 
Give it a name. Role: Project > Owner.
Create key. Save json file as CRED_FILE.json. Click Done
'
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# Step 1: Enable GCP Dynamic Secrets
#-------------------------------------------------------------------------------\n"
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')

#--- This block allows us to start dev instance of vault if it is not running.
if ! VAULT_ADDR=http://127.0.0.1:8200 vault status > /dev/null; then
export VAULT_TOKEN=root
green "Start Vault dev"
pe "vault server -dev -dev-root-token-id=$VAULT_TOKEN -dev-listen-address=0.0.0.0:8200 > /tmp/vault.log 2>&1 &"
pe "vault login root"

green "Enable audit device, so you can examine logs later"
pe "vault audit enable file file_path=/tmp/audit.log log_raw=true"
fi
#-------------------------------------------------------------------------------

echo
green "#--- Enable GCP Dynamic Secrets on Vault"
pe "vault secrets enable -path=gcp gcp"

# Don't need to do this for GCP. Can apply TTL at connection level.
# green "Tune the default lease for the AWS secrets engine to 2 minutes."
# pe "vault secrets tune -default-lease-ttl=2m gcp/"

cyan "Configure the credentials that Vault uses to communicate with GCP to generate the IAM credentials:"
echo
green 'Replace "CRED_FILE.json" with yours. ttl determines life of credentials.'
pe "vault write gcp/config credentials=@../CRED_FILE.json \
  ttl=180 max_ttl=3600"

echo
green '#--- Create binding configuration.'
pe 'cat > /tmp/mybindings.hcl <<EOF
      resource "//cloudresourcemanager.googleapis.com/projects/pphan-test-app-dev" {
        roles = ["roles/editor"]
      }
EOF'
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE VAULT GCP ROLE SET
#-------------------------------------------------------------------------------\n"

echo
cyan 'Configure a GCP role set that associates resources to roles. 
When users generate credentials, they are generated against this role.'
echo

pe 'vault write gcp/roleset/key-role-set \
    project="pphan-test-app-dev" \
    secret_type="service_account_key" \
    bindings=@/tmp/mybindings.hcl'

pe vault read gcp/roleset/key-role-set -format=json | jq -r .data.service_account_email
pe 'export GCP_IAM_ACCOUNT=$(vault read gcp/roleset/key-role-set -format=json | jq -r .data.service_account_email)'

echo
green "#--- Confirm"
pe "gcloud iam service-accounts list"
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# Step 2: Usage
#-------------------------------------------------------------------------------\n"
echo

green 'Show current keys for email vault<key-role-set>-* in GCP IAM.'
pe 'gcloud iam service-accounts keys list --iam-account=$GCP_IAM_ACCOUNT'
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE A NEW SET OF CREDENTIALS
#-------------------------------------------------------------------------------\n"

echo
green 'Generate a new credential by reading from the "/key" endpoint with the name of the role:'

echo "How many GCP users do you want to create (enter a number):"
read GCPCREDS
for i in $(seq 1 $GCPCREDS); do
    pe "vault read gcp/key/key-role-set -format=json | tee /tmp/key-role-set${i}.txt | jq -r"
    echo ""
done

yellow 'Note the lease_id. You will need that value to revoke the credentials.'
echo

echo
green '#--- Confirm keys for email vault<key-role-set>-* is created in GCP IAM.'
pe 'gcloud iam service-accounts keys list --iam-account=$GCP_IAM_ACCOUNT'
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# Step 3: Revoking the secret
#-------------------------------------------------------------------------------\n"

cyan 'What if these credentials were leaked? We can revoke the credentials.'
pe "export GCP_LEASE_ID=$(jq -r .lease_id < /tmp/key-role-set1.txt)"
pe "vault lease revoke $GCP_LEASE_ID"

yellow "#--- Confirm the GCP Service account key is no longer there"
pe 'gcloud iam service-accounts keys list --iam-account=$GCP_IAM_ACCOUNT'
echo
cyan 'What if all my credentials for a role were leaked? Revoke with a prefix.'
pe "vault lease revoke -prefix gcp/key/key-role-set"
pe 'gcloud iam service-accounts keys list --iam-account=$GCP_IAM_ACCOUNT'
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE A NEW SET OF CREDENTIALS USING API
#-------------------------------------------------------------------------------\n"

echo
green "#--- Create lease"
pe 'curl -s -H "X-Vault-Token: $VAULT_TOKEN" http://127.0.0.1:8200/v1/gcp/key/key-role-set | jq "." > /tmp/key-role-set2.txt'
pe 'export LEASE_ID=$(jq -r ".lease_id" < /tmp/key-role-set2.txt)'

echo
green "#--- List leases"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" -X LIST http://127.0.0.1:8200/v1/sys/leases/lookup/gcp/key/key-role-set | jq ".data.keys" '

echo
green "#--- Renew leases"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" -X PUT http://127.0.0.1:8200/v1/sys/leases/renew/$LEASE_ID | jq "."'

echo
green "#--- Revoke leases"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" -X PUT http://127.0.0.1:8200/v1/sys/leases/revoke/$LEASE_ID | jq "."'


cyan "#-------------------------------------------------------------------------------
# CLEAN UP - REMOVE ROLE SET
#-------------------------------------------------------------------------------\n"
green "Remove the service account. This doesn't get removed when keys expire."
pe 'vault delete gcp/roleset/key-role-set'
# pe 'curl -X DELETE -H "X-Vault-Token: $VAULT_TOKEN" http://127.0.0.1:8200/v1/gcp/roleset/key-role-set'
pe 'gcloud iam service-accounts list'

echo ""
white "This concludes the GCP dynamic secrets engine component of the demo."
p "Press any key to return to menu..."