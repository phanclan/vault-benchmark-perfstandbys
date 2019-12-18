. env.sh
set -e
shopt -s expand_aliases
alias dc="docker-compose"

tput clear
cyan "#-------------------------------------------------------------------------------
# NAMESPACES
#-------------------------------------------------------------------------------\n"

cyan "#-------------------------------------------------------------------------------
# CREATE NAMESPACES
#-------------------------------------------------------------------------------\n"
set +e
vault namespace create education
vault namespace create -namespace=education training
vault namespace create -namespace=education certification
set -e

cyan "#-------------------------------------------------------------------------------
# WRITE POLICIES
#-------------------------------------------------------------------------------\n"

green "Policy for education admin"
tee ./vault/files/edu-admin.hcl <<EOF
# Manage namespaces
path "sys/namespaces/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List policies
path "sys/policies/acl" {
  capabilities = ["list"]
}

# Enable and manage secrets engines
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# List available secrets engines
path "sys/mounts" {
  capabilities = [ "read" ]
}

# Create and manage entities and groups
path "identity/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage tokens
path "auth/token/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

green "Policy for training admin"
cat > ./vault/files/training-admin.hcl <<EOF
# Created by $0
# Manage namespaces
path "sys/namespaces/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage policies
path "sys/policies/acl/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List policies
path "sys/policies/acl" {
  capabilities = ["list"]
}

# Enable and manage secrets engines
path "sys/mounts/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}

# List available secrets engines
path "sys/mounts" {
  capabilities = [ "read" ]
}
EOF

green "Create edu-admin policy under 'education' namespace"
vault policy write -namespace=education edu-admin ./vault/files/edu-admin.hcl

green "Create training-admin policy under 'education/training' namespace"
vault policy write -namespace=education/training training-admin ./vault/files/training-admin.hcl



cyan "#-------------------------------------------------------------------------------
# SETUP ENTITIES AND GROUPS
#-------------------------------------------------------------------------------\n"
green "# First, you need to enable userpass auth method"
set +e
vault auth enable -namespace=education userpass
set -e

green "# Create a user 'bob'"
vault write -namespace=education \
        auth/userpass/users/bob password="training"

green "# Create an entity for Bob Smith with 'edu-admin' policy attached"
# Save the generated entity ID in entity_id.txt file
vault write -namespace=education -format=json identity/entity name="Bob Smith" \
        policies="edu-admin" | jq -r ".data.id" > /tmp/entity_id.txt

green "# Get the mount accessor for userpass auth method and save it in accessor.txt file"
vault auth list -namespace=education -format=json \
        | jq -r '.["userpass/"].accessor' > /tmp/accessor.txt

green "# Create an entity alias for Bob Smith to attach 'bob'"
vault write -namespace=education identity/entity-alias name="bob" \
        canonical_id=$(cat /tmp/entity_id.txt) mount_accessor=$(cat /tmp/accessor.txt)

green '# Create a group, "Training Admin" in education/training namespace with Bob Smith entity as its member'
vault write -namespace=education/training identity/group \
        name="Training Admin" policies="training-admin" \
        member_entity_ids=$(cat /tmp/entity_id.txt)


tput clear
echo "#-------------------------------------------------------------------------------
# TEST THE BOB SMITH ENTITY
#-------------------------------------------------------------------------------\n"

echo "Log in as bob into the education namespace:"
vault login -namespace=education -method=userpass \
        username="bob" password="training"

echo "# Set the target namespace as an env variable"
export VAULT_NAMESPACE="education"

echo "# Create a new namespace called 'web-app'"
VAULT_NAMESPACE="education" vault namespace create web-app

echo "# Enable key/value v2 secrets engine at edu-secret"
set +e
vault secrets enable -path=edu-secret kv-v2
set -e

tput clear
echo "#-------------------------------------------------------------------------------
# TEST THE TRAINING ADMIN GROUP
#-------------------------------------------------------------------------------\n"

# Set the target namespace as an env variable
# export VAULT_NAMESPACE="education/training"

# Create a new namespace called 'vault-training'
VAULT_NAMESPACE="education/training" vault namespace create vault-training

# Enable key/value v1 secrets engine at team-secret
VAULT_NAMESPACE="education/training" vault secrets enable -path=team-secret -version=1 kv

echo "#-------------------------------------------------------------------------------
# TEST THE TRAINING ADMIN GROUP - NEGATIVE TESTING
#-------------------------------------------------------------------------------\n"

VAULT_NAMESPACE="education/certification" vault namespace create vault-training
VAULT_NAMESPACE="education/certification" vault secrets enable -path=team-secret -version=1 kv

#-------------------------------------------------------------------------------
