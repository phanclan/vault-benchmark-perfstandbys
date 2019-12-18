. env.sh
export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
export VAULT_TOKEN=${VAULT_TOKEN:-'root'}

tput clear
cyan "#-------------------------------------------------------------------------------
# Running: $0: ENABLE USER PASSWORD AUTHENTICATION
#-------------------------------------------------------------------------------\n"
echo
cyan "Similar to the secrets engine, you enable an authentication method.

As discussed, Vault has multiple authentication methods."
echo
green "First, check to see what is enabled."
echo ""
white "COMMAND: vault auth list"
pe "vault auth list"

yellow "Currently there is only the token authentication available."
echo
green "#--- Enable the userpass method."
echo
white "COMMAND: vault auth enable userpass"
echo
pe "vault auth enable userpass"

green "Confirm what authentication methods are available now."
pe "vault auth list"
p "Press Enter to continue"


tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE USERS TO INTERACT WITH VAULT
#-------------------------------------------------------------------------------\n"
echo
cyan "Up until now we've been interacting with Vault via the root account.
This is not a best practice, and is only for initial configuraiton, demo or emergencies."
echo
green "Create users that can consume Vault and assign a role to define authorization."
echo ""
white "COMMAND: vault write auth/userpass/users/<user_name> password=\"<a password>\" policies=\"<a policy name>\""
echo ""
pe 'vault write auth/userpass/users/beaker password="meep" policies="default"'

pe 'vault write auth/userpass/users/bunsen password="honeydew" policies="base"'

cyan "You should now be able to authenticate to the UI. You can also authenticate via CLI/API using these
credentials, with which upon a successful login, Vault will issue a token for use with API calls
or CLI commands that can then be used to access secrets or functions of Vault."
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# LOGIN INTO VAULT WITH NEW USER
#-------------------------------------------------------------------------------\n"
echo ""
green "Demo logging in to Vault via CLI."
echo ""
white "COMMAND: vault login -method=userpass username=<user_name> password=\"<password>\""
echo ""
pe 'vault login -method=userpass username=beaker password="meep"'
p "Press Enter to continue"

green "Demo logging in to Vault via API."
echo ""
white "curl -X POST -d '{\"password\": \"honeydew\"}' $VAULT_ADDR/v1/auth/userpass/login/bunsen | jq"
p "Press Enter to continue"

curl -H -X POST --data '{"password": "honeydew"}' $VAULT_ADDR/v1/auth/userpass/login/bunsen | \
  jq 'del(.lease_id, .data, .wrap_info, .warnings)'
p "Press Enter to continue"

tput clear
yellow "This concludes the username authentication component of the demo."
p "Press Enter to continue"

green "Create IT user"
pe "vault write auth/userpass/users/deepak password=thispasswordsucks policies=kv-it,kv-user-template"

cyan "ENGINEERING SCENARIO"
echo
green "Create Engineering user"
pe "vault write auth/userpass/users/chun password=thispasswordsucks policies=kv-user-template"
# Moved db-engineering policy to group
# Moved kv-user-template to entity
p "Press Enter to continue"


tput clear
cyan "#-------------------------------------------------------------------------------
# Task 1: Create an Entity with Alias
#-------------------------------------------------------------------------------\n"
echo

white "Scenario: User Bob Smith at ACME Inc. has two sets of credentials: bob and bsmith. 
To manage his accounts and link them to identity Bob Smith in team QA, you are going to create an entity for Bob.
"
echo
cyan "You are going to create a new entity with base policy assigned. 
The entity defines two entity aliases with each having a different policy assigned.
"
echo
green "List all existing policies:"
pe 'vault policy list'

yellow "Make sure you see the following policies:
base default team-eng team-qa test root "

green "Find the mount accessor for the userpass auth method:"
pe "vault auth list"

green "In the output, locate the Accessor value for userpass:"
# Save the accessor value for userpass in a file named, userpass_accessor.txt.
vault auth list -format=json | jq -r '."userpass/".accessor' | tee /tmp/userpass_accessor.txt

cyan "#-------------------------------------------------------------------------------
# Step: Create an Entity
#-------------------------------------------------------------------------------\n"
echo

green 'Create a new entity named "engineer-chun" and save its entity ID in entity_id.txt for later use.'
pe 'vault write -format=json identity/entity name="engineer-chun" policies="kv-user-template" \
     metadata=organization="ACME Inc." metadata=team="QA" \
     | jq -r ".data.id" | tee /tmp/entity_id.txt'

yellow 'NOTE: The metadata are passed in metadata=<key>=<value> format. 
In the above command, the entity has organization and team as its metadata.'
echo

cyan 'For convenience, the above command used jq to parse the resulting JSON output, 
retrieved the entity ID, and saved it in a file (/tmp/entity_id.txt). 
Therefore, you did not see the actual response. 
The command returns the entity ID as follow:

Key        Value
---        -----
aliases    <nil>
id         631256b1-8523-9838-5501-d0a1e2cdad9c

The id is the entity ID.'

cyan "#-------------------------------------------------------------------------------
# Step: Create an Entity Alias
#-------------------------------------------------------------------------------\n"
echo

green	'Add the user chun to the engineer-chun entity by creating an entity alias:'
pe 'vault write identity/entity-alias name="chun" \
canonical_id=$(cat /tmp/entity_id.txt) \
mount_accessor=$(cat /tmp/userpass_accessor.txt) '

white 'The name "chun" is the username you created in the userpass at Step 1.1.2.
The output should look similar to:
Key             Value
---             -----
canonical_id    631256b1-8523-9838-5501-d0a1e2cdad9c
id              873f7b12-dec8-c182-024e-e3f065d8a9f1 '

green 'Review the entity details:'
pe "vault read identity/entity/id/$(cat /tmp/entity_id.txt)"

green "Passing the -format=json flag, the output will be printed in JSON format."

pe "vault read -format=json identity/entity/id/$(cat /tmp/entity_id.txt)"

yellow "The output includes the entity aliases, metadata (organization, and team), and base policy."

green 'If you do not know the entity ID, you can list all entity IDs.'
pe "vault list identity/entity/id"

green "Open a web browser and enter the following address to launch Vault UI: 
http://<workstation_ip_address>:8200/ui
Login with your initial root token"
pe "open http://localhost:8200/ui/vault/access/identity/entities"

green "Select engineer-chun. Then click the Aliases tab. You should see chun and ? listed."

tput clear
cyan "#-------------------------------------------------------------------------------
# Task 2: Test the entity
#-------------------------------------------------------------------------------\n"
echo

# unset VAULT_TOKEN
green "Login as IT user"
pe "VAULT_TOKEN='' vault login -method=userpass username=deepak password=thispasswordsucks"

green "Test KV puts to allowed paths"
pe "vault kv put kv-blog/it/servers/hr/root password=rootntootn"

green "Test KV gets to allowed paths"
pe "vault kv get kv-blog/it/servers/hr/root"

# clear
unset VAULT_TOKEN
green "Login as Engineering user"
pe "vault login -method=userpass username=chun password=thispasswordsucks"
yellow "The token generated upon a successful authentication as user chun has 
**default** and **kv-user-template** policies attached (token_policies)."
echo
yellow "The policy that chun inherited from its entity is db-engineering policy (identity_policies)."

pe "vault read -format=json db-blog/creds/mother-engineering-full-1h | tee /tmp/mother-engineering-full-1h.creds"
pe "jq -r '.data | .[\"PGUSER\"] = .username | .[\"PGPASSWORD\"] = .password | del(.username, .password) | to_entries | .[] | .key + \"=\" + .value ' /tmp/mother-engineering-full-1h.creds > /tmp/.temp_db_creds"

green "Set the postgres environment variables to the dynamic creds so we can run PSQL"
pe "PGUSER=`jq -r .data.username /tmp/mother-engineering-full-1h.creds`"
pe "PGPASSWORD=`jq -r .data.password /tmp/mother-engineering-full-1h.creds`"

green "Turn off globbing for the database query in an environment variable"
pe "set -o noglob"
pe "QUERY='select name,description from engineering.catalog;'"
pe "psql"

clear

cyan "Negative Tests. Expect failures"
yellow "Can these credentials be used to query the HR schema?"
pe "QUERY='select * from hr.people;'"
pe "psql"

yellow "Can the Vault token read from other areas?"
pe "vault read db-blog/creds/mother-full-read-1h"
pe "vault kv get kv-blog/it/servers/hr/root"

tput clear
cyan "#-------------------------------------------------------------------------------
# Task 3: Create an Internal Group
#-------------------------------------------------------------------------------\n"
echo

white "Now, you are going to create an internal group named engineers. 
Its member is engineer-chun entity that you created in Task 1."

green "Review the team-eng policy"
pe "vault policy read db-engineering"

green "Create an internal group named engineers and add engineer-chun entity as a group member."
green 'Assign the team-eng policy to the engineers group.
For later use, parse the JSON output and save the generated group ID in a file named, group_id.txt.'
pe 'vault write -format=json identity/group name="engineers" \
  policies="db-engineering" \
  member_entity_ids=$(cat /tmp/entity_id.txt) \
  metadata=team="Engineering" metadata=region="North America" \
  | jq -r ".data.id" | tee /tmp/group_id.txt' 

yellow 'Due to the extra command (jq -r ".data.id" > group_id.txt), you do not see the output. 
The command output displays the group ID and name.
Example output:
Key     Value
---     -----
id      81bdac90-284a-7b8c-6289-5fa7693bcb4a
name    engineers'

green 'List the existing groups by IDs'
pe 'vault list identity/group/id'

green 'List the existing groups by its name'
pe 'vault list identity/group/name'

green 'Read the details of the group engineers.'
pe "vault read identity/group/id/$(cat /tmp/group_id.txt)"

tput clear
cyan "#-------------------------------------------------------------------------------
# Task 4: Test the Internal Group
#-------------------------------------------------------------------------------\n"
echo
