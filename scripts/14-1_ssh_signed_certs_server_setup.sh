#!/usr/bin/env bash
. env.sh
# set -e
shopt -s expand_aliases
alias dc="docker-compose"

# export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
# export VAULT_ADDR=http://127.0.0.1:8200
if ! consul kv get service/vault/root-token; then
export VAULT_TOKEN=${VAULT_TOKEN:-'root'}
else
export VAULT_TOKEN=$(consul kv get service/vault/root-token)
fi

tput clear
cyan "#-------------------------------------------------------------------------------
# Vault SSH CA
#-------------------------------------------------------------------------------\n"
green "Load up before and after diagrams"
open https://blog.octo.com/wp-content/uploads/2018/12/01_ssh_keys.png
open https://blog.octo.com/wp-content/uploads/2018/12/02_vault-1024x694.png

green "Authenticate to Vault"
vault login $VAULT_TOKEN

tput clear
cyan "#-------------------------------------------------------------------------------
# VAULT SSH CLIENT SIGNING
#-------------------------------------------------------------------------------\n"

# CREATE SEPARATE SSH SIGNING ENGINES - ONE PER TEAM
#-------------------------------------------------------------------------------
green "#--- Enable SSH secrets engine for signing client keys - TEAM 1"
vault secrets enable -path ssh-client-signer-team-1 ssh

green "#--- Enable SSH secrets engine for signing client keys - TEAM 2"
vault secrets enable -path ssh-client-signer-team-2 ssh


# CONFIGURE CA FOR SIGNING CLIENT KEYS 
#-------------------------------------------------------------------------------
echo
yellow "You can use an existing keypair or Vault can generate a keypair for you."
echo
green "#--- Create client CA certificate - TEAM 1"
vault write ssh-client-signer-team-1/config/ca generate_signing_key=true

green "#--- Create client CA certificate - TEAM 2"
vault write -field=public_key ssh-client-signer-team-2/config/ca generate_signing_key=true
# You can pipe it to a file: | tee vault/config/tmp/trusted-user-ca-keys.pem
# Need to distribute to any host we want to ssh to using client certificates."

p "Press Enter to continue..."

# ADD PUBLIC KEY TO TARGET HOST'S SSHD CONFIGURATION 
#-------------------------------------------------------------------------------
tput clear
green "#--- Add the SSH CA public key to our trusted keys (target - ex: python container)"
# Have the SSH hosts download Vault CA public key
tee python/sshd_vault_server.sh <<"EOF"
# In this example, my one SSH Server is trusting both Team CA's.
curl -s http://vc1s1:8200/v1/ssh-client-signer-team-1/public_key | tee -a /etc/ssh/trusted-user-ca-keys.pem
curl -s http://vc1s1:8200/v1/ssh-client-signer-team-2/public_key | tee -a /etc/ssh/trusted-user-ca-keys.pem
echo "TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem" | tee -a /etc/ssh/sshd_config
echo "Restart sshd on Docker container"
pkill sshd
/usr/sbin/sshd -D -e &
echo "Add users ubuntu, centos, bob, sally for later"
for i in {ubuntu,centos,bob,sally}; do
  useradd $i -p $(head /dev/urandom | tr -dc A-Za-z0-9 | head -c10) -m
done
# Need to create password for users, though we won't use it.
EOF
chmod +x python/sshd_vault_server.sh
dc exec python bash python/sshd_vault_server.sh
p "Press Enter to continue..."


tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE ROLES TO SIGN CLIENT KEYS
#-------------------------------------------------------------------------------\n"
# Create role per team (ex team-1, team-2) 
# Create role per user for more granularity

# Sample
    # Used for ssh signed certs demo.
    # cat > vault/config/clientrole.json <<EOF
    # {
    #   "allow_user_certificates": true,
    #   "allowed_users": "*",
    #   "default_user": "root",
    #   "default_extensions": [
    #     {
    #       "permit-pty": ""
    #     }
    #   ],
    #   "key_type": "ca",
    #   "key_id_format": "vault-{{role_name}}-{{token_display_name}}-{{public_key_hash}}",
    #   "ttl": "60m0s"
    # }
    # EOF
    # # changed default_user from vagrant to root


# CREATE ROLE CONFIGURATION FOR NON-ROOT
#-------------------------------------------------------------------------------\n"

green "#--- Create role for SSH as a regular user:"
tee vault/config/regular-user-role.hcl <<EOF
{
    "allow_user_certificates": true,
    "allowed_users": "centos,ec2-user,ubuntu",
    "default_user": "ec2-user",
    "default_extensions": [
        {
          "permit-pty": ""
        }
    ],
    "key_type": "ca",
    "ttl": "30m0s",
    "allow_user_key_ids": "false",
    "key_id_format": "{{token_display_name}}"
}
EOF
# - `allow_user_certificates`: specifies that signed certificates will be user certificates, instead of host certificates
# - `allowed_users`: allows this role to sign for any users. 
#   -  Can use * for allowed_users.
#   -  If you wanted to create a role which allowed only keys for a particular service name 
#   -  (say you wanted only to sign keys for an ansible user if you were using Ansible)
# - `default_user`: default username 
# - `default_extensions` sets default certificate options when it signs key. 
#     In this case, `permit-pty` allows the key to get a PTY on login, permitting interactive terminal sessions. 
#     For more information, consult the ssh-keygen documentation
# - `key_type`: specifies type of credentials: ca (SSH CA signing), otp, dynamic
# - `ttl`: specifies signed certificate will be valid for no more than 30 minutes.


yellow "Regular role - allow clients to request a signed certificate to SSH as 
centos,ec2-user, or ubuntu only. No root.
Ensures that users get a shell upon successful login 'permit-pty'
Sets a default principal (i.e. login user) when clients don't specify any principals.
Also prevents users from specifying a key ID, which gets logged by the SSH daemon.
Using {{token_display_name}} forces the key ID to be the name of the Vault auth token."

echo
green "#--- Write the roles to Vault"
pe "vault write ssh-client-signer/roles/regular @vault/config/regular-user-role.hcl"

p "Press Enter to continue..."

# CREATE ROLE CONFIGURATION USING BASH FUNCTION
#-------------------------------------------------------------------------------\n"
write_ssh_role () {
tee vault/config/regular-role-${TEAM}-${USER}.hcl <<EOF
{
    "allow_user_certificates": true,
    "allowed_users": "${SSH_USER}",
    "default_user": "",
    "default_extensions": [
        {
          "permit-pty": ""
        }
    ],
    "key_type": "ca",
    "ttl": "${TTL}m0s",
    "allow_user_key_ids": "false",
    "key_id_format": "{{token_display_name}}"
}
EOF
echo vault write ssh-client-signer-${TEAM}/roles/${USER} @vault/config/regular-role-${TEAM}-${USER}.hcl
vault write ssh-client-signer-${TEAM}/roles/${USER} @vault/config/regular-role-${TEAM}-${USER}.hcl
echo
}

# CREATE ROLES FOR TEAM 1
#-------------------------------------------------------------------------------\n"
TEAM=team-1 TTL=30 SSH_USER=ubuntu USER=ubuntu
write_ssh_role

TEAM=team-1 TTL=30 SSH_USER=bob USER=bob
write_ssh_role

# CREATE ROLE FOR TEAM 2
#-------------------------------------------------------------------------------\n"
TEAM=team-2 TTL=30 SSH_USER=ubuntu USER=ubuntu
write_ssh_role

TEAM=team-2 TTL=30 SSH_USER=sally USER=sally
write_ssh_role

# CREATE ROLE FOR ROOT
#-------------------------------------------------------------------------------\n"
tput clear
green "#--- Create a role for SSH as root:"
write_ssh_root_role () {
tee vault/config/root-user-role-${TEAM}.hcl <<EOF
{
    "allow_user_certificates": true,
    "allowed_users": "${SSH_USER}",
    "default_extensions": [
        {
          "permit-pty": ""
        }
    ],
    "key_type": "ca",
    "default_user": "",
    "ttl": "${TTL}m0s",
    "allow_user_key_ids": "false",
    "key_id_format": "{{token_display_name}}"
}
EOF
echo vault write ssh-client-signer-${TEAM}/roles/root-${TEAM} @vault/config/root-user-role-${TEAM}.hcl
vault write ssh-client-signer-${TEAM}/roles/root-${TEAM} @vault/config/root-user-role-${TEAM}.hcl
echo
}

# CREATE ROLE FOR ROOT
#-------------------------------------------------------------------------------\n"
TEAM=team-1 TTL=3 SSH_USER=root
write_ssh_root_role

echo
yellow "Changed allowed_users and lowered ttl. This role can be used for SSH’ing as root"

p "Press Enter to continue..."

echo
cyan "(NEED EDITING) We’ve made the process easy for our users. 
When users need to SSH as a regular user, they hit the ssh-client/sign/regular path.
Or, can also use a personal path ex. ssh-client-signer-${TEAM}/roles/${USER} path.
When users need (and are authorized) to SSH as root, they hit the ssh-client/sign/root path."
p "Press Enter to continue..."


tput clear
cyan "#-------------------------------------------------------------------------------
# VAULT POLICIES FOR SSH
#-------------------------------------------------------------------------------\n"

cyan "Policies allow us to define which users can request certificates from 
(i.e. write data to) which paths. Not all users should be able to request a 
certificate which would allow them to SSH as root. However, we assume all users
should be able to SSH as a regular user."

# POLICY FOR REGULAR USER
#-------------------------------------------------------------------------------\n"
echo
green "#--- Create a policy for regular users:"
tee vault/config/regular-user-role-policy.hcl <<EOF
# Allow user to run: vault secrets list
path "sys/mounts" {
  capabilities = ["list","read"]
}
path "ssh-client-signer/sign/regular" {
    capabilities = ["create","update"]
}
EOF

echo
green "#--- Write the policies to Vault:"
vault policy write ssh-regular-user vault/config/regular-user-role-policy.hcl

echo
green "#--- Create a policy for regular users"
create_ssh_policy () {
vault policy write ${TEAM}-ssh -<<EOF
path "ssh-client-signer-${TEAM}/sign/regular" {
  capabilities = ["create","update"]
}
path "ssh-client-signer-${TEAM}/sign/team-1" {
  capabilities = ["create","update"]
}
path "ssh-client-signer-${TEAM}/sign/{{identity.entity.name}}" {
    capabilities = ["create","update"]
}
EOF
}

green "#--- Create a policy for regular users - TEAM 1"
TEAM=team-1
create_ssh_policy && vault policy read ${TEAM}-ssh

echo
green "#--- Create a policy for regular users - TEAM 2"
TEAM=team-2
create_ssh_policy && vault policy read ${TEAM}-ssh

p "Press Enter to continue..."

# POLICY FOR ROOT USER
#-------------------------------------------------------------------------------\n"
green "#--- Create a policy for admins - who will SSH as root:"
# tee vault/config/root-user-role-policy.hcl <<EOF
vault policy write ssh-root-user -<<EOF
path "ssh-client-signer-team-1/sign/root-team-1" {
    capabilities = ["create","update"]
}
EOF

echo
yellow "In both cases, we allow users with the attached policy 
to create new data and update existing data at the respective paths."
p "Press Enter to continue..."


tput clear
cyan "#-------------------------------------------------------------------------------
# ENABLE USERPASS AUTH AND USER
#-------------------------------------------------------------------------------\n"

green "#--- Enable userpass secrets engine"
pe "vault auth enable userpass"

green "#--- Create test users: withoutroot and withroot"
vault write auth/userpass/users/withoutroot password="test" policies="ssh-regular-user,team-1-ssh"
vault write auth/userpass/users/withroot password="test" policies="ssh-regular-user,ssh-root-user"

vault write auth/userpass/users/$(whoami) password=test policies=ssh-regular-user

# Create a User for Bob and Sally
vault write auth/userpass/users/bob password=test policies="base"
vault write auth/userpass/users/sally password=test policies="base"

p "Press Enter to continue..."


# Create an Entity and Aliases for Each Team Member
#-------------------------------------------------------------------------------\n"

# Save userpass accessor id.
vault auth list -format=json | jq -r '."userpass/".accessor' | tee /tmp/userpass_accessor.txt

# DEFINE CREATE_ENTITY FUNCTION
#-------------------------------------------------------------------------------\n"
# - Create entity. Save entity id.
create_entity () {
echo "vault write -format=json identity/entity name=${ENTITY_NAME} policies=${ENTITY_POLICY} \\
     metadata=organization='ACME Inc.' metadata=team=${ENTITY_METADATA} \\
     | jq -r '.data.id' | tee /tmp/entity_id_${ENTITY_NAME}.txt"

vault write -format=json identity/entity name=${ENTITY_NAME} policies=${ENTITY_POLICY} \
     metadata=organization="ACME Inc." metadata=team=${ENTITY_METADATA} \
     | jq -r ".data.id" | tee /tmp/entity_id_${ENTITY_NAME}.txt
}

# DEFINE CREATE_ALIAS FUNCTION
#-------------------------------------------------------------------------------\n"
create_alias () {
vault write identity/entity-alias name="${ENTITY_NAME}" \
  canonical_id=$(cat /tmp/entity_id_${ENTITY_NAME}.txt) \
  mount_accessor=$(cat /tmp/userpass_accessor.txt)
}

# Create Entity for Chun. Create Alias - One Per Auth Method
ENTITY_NAME=chun ENTITY_POLICY="ssh-regular-user,team-1-ssh" ENTITY_METADATA="Team-1"
create_entity && create_alias

# Create entity for withoutroot
ENTITY_NAME=withoutroot ENTITY_POLICY=team-1-ssh ENTITY_METADATA="Team-1"
create_entity

# Create an Entity for Bob. Create Alias - One Per Auth Method
#-------------------------------------------------------------------------------\n"
ENTITY_NAME=bob ENTITY_POLICY="ssh-regular-user,team-1-ssh" ENTITY_METADATA="Team-1"
create_entity && create_alias

# Create an Entity for Sally. Create Alias - One Per Auth Method
#-------------------------------------------------------------------------------\n"
ENTITY_NAME=sally ENTITY_POLICY="ssh-regular-user,team-2-ssh" ENTITY_METADATA="Team-2"
create_entity && create_alias

tput clear
cyan "#-------------------------------------------------------------------------------
# SSH CLIENT WORKFLOW
#-------------------------------------------------------------------------------\n"

green "#--- Generate an RSA key pair if you don’t already have one:"
# ssh-keygen -qf $HOME/.ssh/id_rsa -t rsa -N ""

#-------------------------------------------------------------------------------\n"
# TESTING FOR BOB IN TEAM-1
#-------------------------------------------------------------------------------\n"
echo
green "#--- Authenticate and get a token from Vault."
unset VAULT_TOKEN
# vault login -path=userpass -method=userpass username=withoutroot password=withoutroot
vault login -path=userpass -method=userpass username=bob password=test

tput clear
green "#--- Request that Vault sign our SSH public key and return the signed certificate:"
#rm -f /Users/pephan/.ssh/vault-signed-cert.pub

# pe "vault write \
#     -field=signed_key \
#     ssh-client-signer/sign/regular \
#     valid_principals="ubuntu,centos" \
#     public_key=@$HOME/.ssh/id_rsa.pub \
#     > $HOME/.ssh/vault-signed-cert.pub"

### Doing this test under root scenario
  # # NEGATIVE TESTING - Request signed cert; Invalid Path
  # yellow "# Should Fail: Path to team-2 is not allowed."
  # vault write -field=signed_key \
  #     ssh-client-signer-team-2/sign/team-2 \
  #     valid_principals="ubuntu" \
  #     public_key=@$HOME/.ssh/id_rsa.pub

# POSITIVE TESTING - Request signed cert
vault write -field=signed_key \
    ssh-client-signer-team-1/sign/bob \
    valid_principals="bob" \
    public_key=@$HOME/.ssh/id_rsa.pub \
    > $HOME/.ssh/vault-signed-cert.pub

chmod 0400 $HOME/.ssh/vault-signed-cert.pub

# View enabled extension, principals, and metadata of the signed key
green "#--- Examine the certificate with ssh-keygen:"
pe "ssh-keygen -Lf $HOME/.ssh/vault-signed-cert.pub"

set +e
# POSITIVE TESTING 
#-------------------------------------------------------------------------------\n"
green "#--- Login as VALID regular user: ubuntu"
ssh -i $HOME/.ssh/id_rsa -i $HOME/.ssh/vault-signed-cert.pub bob@127.0.0.1

# NEGATIVE TESTING
#-------------------------------------------------------------------------------\n"
green "#--- Login as INVALID regular user: ec2-user"
pe "ssh -i $HOME/.ssh/id_rsa -i $HOME/.ssh/vault-signed-cert.pub ec2-user@127.0.0.1"
yellow "You will be prompted for a password."

p "Press Enter to continue..."


#-------------------------------------------------------------------------------\n"
# TESTING FOR SALLY IN TEAM2
#-------------------------------------------------------------------------------\n"
vault login -path=userpass -method=userpass username=sally password=test
vault write -field=signed_key \
    ssh-client-signer-team-2/sign/team-2 \
    valid_principals="ubuntu" \
    public_key=@$HOME/.ssh/id_rsa.pub \
    > $HOME/.ssh/vault-signed-cert.pub
ssh-keygen -Lf $HOME/.ssh/vault-signed-cert.pub
ssh -i $HOME/.ssh/id_rsa -i $HOME/.ssh/vault-signed-cert.pub ubuntu@127.0.0.1

p "Press Enter to continue..."


tput clear
red "#-------------------------------------------------------------------------------
# NEGATIVE TESTING FOR ROOT 
#-------------------------------------------------------------------------------\n"

green "#--- Request that Vault sign our SSH public key with root role and return the signed certificate:"
pe "vault write -field=signed_key ssh-client-signer/sign/root \
    valid_principals="ubuntu" public_key=@$HOME/.ssh/id_rsa.pub \
    > $HOME/.ssh/vault-signed-cert.pub"

echo
yellow "Should Fail - Permission denied 
Why? Using token for user 'withoutroot' who does not have permissions to 'ssh-client-signer/sign/root'
"

echo
green "#--- Authenticate as withroot and try again"
unset VAULT_TOKEN
vault login -path=userpass -method=userpass username=withroot password=withroot

green "#--- Request that Vault sign our SSH public key with root role and return the signed certificate:"
pe "vault write -field=signed_key ssh-client-signer/sign/root \
    valid_principals="ubuntu" public_key=@$HOME/.ssh/id_rsa.pub \
    > $HOME/.ssh/vault-signed-cert.pub"

yellow "Should Fail - ubuntu is not a valid value for valid_principals 
Why? root role only has a single valid principal: root."
p "Press Enter to continue..."

tput clear
cyan "#-------------------------------------------------------------------------------
# POSITIVE TESTING - for root 
#-------------------------------------------------------------------------------\n"

green "#--- Try to get certificate with valid_principals of root or leave it out. Default will be root"
vault write -field=signed_key ssh-client-signer-team-1/sign/root-team-1 \
    valid_principals="root" public_key=@$HOME/.ssh/id_rsa.pub \
    > $HOME/.ssh/vault-signed-cert.pub

green "#--- Examine the certificate with ssh-keygen:"
ssh-keygen -Lf $HOME/.ssh/vault-signed-cert.pub

yellow "We now see that the key ID reflects the user we authenticated with 
and the Principals field is set to root."

echo
green "#--- Login as root"
set +e
pe "ssh -i $HOME/.ssh/id_rsa -i $HOME/.ssh/vault-signed-cert.pub root@127.0.0.1"


tput clear
red "#-------------------------------------------------------------------------------
# EXAMPLE BASH FUNCTION 
#-------------------------------------------------------------------------------\n"
  
ssh_vault () {
export VAULT_ADDR="http://localhost:${VAULT_PORT:-10101}"
vault write -field=signed_key ssh-client-signer/sign/regular \
  valid_principals="ubuntu" public_key=@$HOME/.ssh/id_rsa.pub \
  > $HOME/.ssh/vault-signed-cert.pub
ssh -i $HOME/.ssh/id_rsa -i $HOME/.ssh/vault-signed-cert.pub ${SSH_USER}@${SSH_SERVER}
}
export SSH_USER="ubuntu"
export SSH_SERVER="127.0.0.1"
ssh_vault

pe "exit"


# Resources
# https://abridge2devnull.com/posts/2018/05/leveraging-hashicorp-vaults-ssh-secrets-engine/
# https://medium.com/hashicorp-engineering/hashicorp-vault-ssh-ca-and-sentinel-79ea6a6960e5
# - Great use case for restricting SSH access
# https://github.com/cneralich/vault_ssh_roles
# - Great use case for restricting SSH access
# https://www.hashicorp.com/resources/manage-ssh-with-hashicorp-vault
# https://gist.github.com/kawsark/587f40541881cea58fbaaf07bb82b1be
# https://www.vaultproject.io/docs/secrets/ssh/signed-ssh-certificates.html
# https://man.openbsd.org/ssh-keygen.1#O

# APPENDIX
#-------------------------------------------------------------------------------\n"
# OTP
# {
#   "allowed_users": "bob",
#   "key_type": "otp",
#   "default_user": "bob",
#   "cidr_list": "0.0.0.0/0",
#   "port": "22"
# }


# TROUBLESHOOTING
# vault read ssh-client-signer-team-1/roles/root-team-1
# vault read ssh-client-signer-team-1/roles/team-1