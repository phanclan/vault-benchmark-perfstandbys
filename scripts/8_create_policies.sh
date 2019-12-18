. env.sh
# export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
# export VAULT_TOKEN=${VAULT_TOKEN:-'root'}

tput clear
cyan "#-------------------------------------------------------------------------------
# Running: $0: CREATE POLICIES
#-------------------------------------------------------------------------------\n"
cyan "Before enabling authentication, you create policies that will be used to grant a role and permissions.

An example role could be a simple as only allowing access to certain secrets.

EXAMPLE POLICY:
---------------"
pe "cat vault/files/base_example.hcl"
p "Press Enter to continue"

echo
green "Load the policy into Vault\n"
echo
white "COMMAND: vault policy write base demofiles/base.hcl"
pe "vault policy write base ./vault/files/base.hcl"

tput clear
cyan "#-------------------------------------------------------------------------------
# LIST AND CHECK POLICIES
#-------------------------------------------------------------------------------\n"
green "Once the policy has been written, check availability..."
echo
white "COMMAND: vault policy list"
pe "vault policy list"

green "Review the policy:"
echo ""
white "COMMAND: vault policy read \<name of policy\>"
echo ""
pe "vault policy read base"

p "Press Enter to continue"


# KV Policies
green "Create KV policy for IT access"
pe "vault policy write kv-it policies/kv-it-policy.hcl"

# DB Policies
green "Create DB policies for access."
pe "cat policies/db-full-read-policy.hcl"
pe "vault policy write db-full-read policies/db-full-read-policy.hcl"
pe "cat policies/db-engineering-policy.hcl"
pe "vault policy write db-engineering policies/db-engineering-policy.hcl"
pe "cat policies/db-hr-policy.hcl"
pe "vault policy write db-hr policies/db-hr-policy.hcl"

# Transit Policies
green 'Create DB transit policies for HR.'
pe "cat policies/transit-hr-policy.hcl"
pe "vault policy write transit-hr policies/transit-hr-policy.hcl"
