. env.sh
# export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
# export VAULT_TOKEN=${VAULT_TOKEN:-'root'}
# export VAULT_ADDR=http://127.0.0.1:8200

tput clear
cyan "#-------------------------------------------------------------------------------
# Running: $0: Generating a dynamic policy
#-------------------------------------------------------------------------------\n"
pe "vault auth list"
pe "UM_ACCESS=$(vault auth list -format=json | jq -r '.["ldap-um/"].accessor')"
pe $"MO_ACCESS=$(vault auth list -format=json | jq -r '.["ldap-mo/"].accessor')"

# green "Generating a dynamic policy under policies/kv-user-template-policy.hcl.  
# This needs to be done because the ACL templates need to know the local LDAP auth method accessors"

tee policies/kv-user-template-policy.hcl << EOF
# Allow full access to the current version of the kv-blog
path "kv-blog/data/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv-blog/data/{{identity.entity.aliases.${UM_ACCESS}.name}}"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}


# Allow deletion of any kv-blog version
path "kv-blog/delete/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/delete/{{identity.entity.aliases.${UM_ACCESS}.name}}"
{
  capabilities = ["update"]
}

# Allow un-deletion of any kv-blog version
path "kv-blog/undelete/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/undelete/{{identity.entity.aliases.${UM_ACCESS}.name}}"
{
  capabilities = ["update"]
}

# Allow destroy of any kv-blog version
path "kv-blog/destroy/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/destroy/{{identity.entity.aliases.${UM_ACCESS}.name}}"
{
  capabilities = ["update"]
}
# Allow list and view of metadata and to delete all versions and metadata for a key
path "kv-blog/metadata/{{identity.entity.aliases.${UM_ACCESS}.name}}/*"
{
  capabilities = ["list", "read", "delete"]
}

path "kv-blog/metadata/{{identity.entity.aliases.${UM_ACCESS}.name}}"
{
  capabilities = ["list", "read", "delete"]
}

# Allow full access to the current version of the kv-blog
path "kv-blog/data/{{identity.entity.aliases.${MO_ACCESS}.name}}/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv-blog/data/{{identity.entity.aliases.${MO_ACCESS}.name}}"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}


# Allow deletion of any kv-blog version
path "kv-blog/delete/{{identity.entity.aliases.${MO_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/delete/{{identity.entity.aliases.${MO_ACCESS}.name}}"
{
  capabilities = ["update"]
}

# Allow un-deletion of any kv-blog version
path "kv-blog/undelete/{{identity.entity.aliases.${MO_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/undelete/{{identity.entity.aliases.${MO_ACCESS}.name}}"
{
  capabilities = ["update"]
}

# Allow destroy of any kv-blog version
path "kv-blog/destroy/{{identity.entity.aliases.${MO_ACCESS}.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/destroy/{{identity.entity.aliases.${MO_ACCESS}.name}}"
{
  capabilities = ["update"]
}
# Allow list and view of metadata and to delete all versions and metadata for a key
path "kv-blog/metadata/{{identity.entity.aliases.${MO_ACCESS}.name}}/*"
{
  capabilities = ["list", "read", "delete"]
}

path "kv-blog/metadata/{{identity.entity.aliases.${MO_ACCESS}.name}}"
{
  capabilities = ["list", "read", "delete"]
}
EOF

pe "vault policy write kv-user-template policies/kv-user-template-policy.hcl"