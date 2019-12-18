#!/bin/bash
set -e

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. demo-magic.sh -d -p -w ${DEMO_WAIT}

cyan "#-------------------------------------------------------------------------------
# Running: $0: SSH SECRETS ENGINE: ONE-TIME SSH PASSWORD
#-------------------------------------------------------------------------------\n"

# set +e
# pkill vault
# set -e
if ! consul kv get service/vault/root-token; then
export VAULT_TOKEN=root
else
export VAULT_TOKEN=$(consul kv get service/vault/root-token)
fi

green "Start Vault dev "
# vault server -dev -dev-root-token-id=$VAULT_TOKEN -dev-listen-address=0.0.0.0:8200 > /tmp/vault.log 2>&1 &

green "Enable audit device, so you can examine logs later"
# vault audit enable file file_path=/tmp/audit.log log_raw=true

tput clear
cyan "#-------------------------------------------------------------------------------
# MOUNT THE SSH SECRETS ENGINE
#-------------------------------------------------------------------------------\n"

# export VAULT_ADDR=http://127.0.0.1:8200

green "#--- Authenticate to Vault"
pe "vault login $VAULT_TOKEN"

green "#--- Enable SSH Secrets Engine"
pe "vault secrets enable -path=ssh ssh"


tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE ROLE FOR SSH - TEAM1 - VAMPIRES
#-------------------------------------------------------------------------------\n"

cyan "Create a role with the key_type parameter set to otp. 
All of the machines represented by the role's CIDR list 
should have vault-ssh-helper properly installed and configured.\n"

white "COMMAND:
vault write <ssh_path>/roles/<team> \
    key_type=otp \
    default_user=<default_user> \
    cidr_list=<x.x.x.x/y>[,<m.m.m.m/n>]"

pe "vault write ssh/roles/vampires \
    key_type=otp \
    default_user=root \
    cidr_list=0.0.0.0/0"


tput clear
cyan "#-------------------------------------------------------------------------------
# VAULT-SSH-HELPER (FOR SSH SERVERS)
#-------------------------------------------------------------------------------\n"

curl -sC - -k https://releases.hashicorp.com/vault-ssh-helper/0.1.4/vault-ssh-helper_0.1.4_linux_amd64.zip -o vault-ssh-helper.zip
unzip -q vault-ssh-helper.zip -d /usr/local/bin
chmod 0755 /usr/local/bin/vault-ssh-helper

green "#--- Create Vault SSH Helper configuration"
mkdir /etc/vault-ssh-helper.d
tee /etc/vault-ssh-helper.d/config.hcl << EOL
vault_addr = "http://vc1s1:8200"
ssh_mount_point = "ssh"
ca_cert = "/etc/vault-ssh-helper.d/vault.crt"
tls_skip_verify = false
allowed_roles = "*"
allowed_cidr_list="10.0.10.0/24"
EOL


tee /etc/vault-ssh-helper.d/config.hcl <<EOF
vault_addr = "http://vc1s1:8200"
ssh_mount_point = "ssh"
tls_skip_verify = true
allowed_roles = "*"
allowed_cidr_list="0.0.0.0/0"
EOF


vault-ssh-helper -dev -verify-only -config=/etc/vault-ssh-helper.d/config.hcl &


tput clear
cyan "#-------------------------------------------------------------------------------
# CONFIGURE PAM (FOR SSH SERVERS)
#-------------------------------------------------------------------------------\n"
green "#--- Backup original configuration"
cp -n /etc/pam.d/sshd.bak /etc/pam.d/sshd.bak
#cp /etc/pam.d/sshd.bak /etc/pam.d/sshd

green "Update PAM sshd configuration"
tee ./python/ssh_otp_update_pam.sh <<"EOF"
#!/bin/bash
sed -i -e 's/^@include common-auth/#@include common-auth/' /etc/pam.d/sshd
echo "auth requisite pam_exec.so quiet expose_authtok log=/tmp/vaultssh.log /usr/local/bin/vault-ssh-helper -config=/etc/vault-ssh-helper.d/config.hcl -dev" >> /etc/pam.d/sshd
echo "auth optional pam_unix.so not_set_pass use_first_pass nodelay" >> /etc/pam.d/sshd
EOF
chmod +x ./python/ssh_otp_update_pam.sh
dc exec python ./python/ssh_otp_update_pam.sh
dc exec python diff /etc/pam.d/sshd /etc/pam.d/sshd.bak

yellow "NOTE: common-auth is the standard Linux authentication module which is commented out in favor of using our custom configuration."


tput clear
cyan "#-------------------------------------------------------------------------------
# MODIFY /etc/ssh/sshd_config FILE (FOR SSH SERVERS)
#-------------------------------------------------------------------------------\n"

echo "Update sshd configuration"
green "Set the following three options:
ChallengeResponseAuthentication yes
PasswordAuthentication no 
UsePAM yes"
echo

green "#--- Backup original configuration"
cp -n /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

green "#--- Update sshd configuration"
tee ./python/ssh_otp_update_sshd.sh <<EOF
#!/bin/bash
sed -i -e '/^ChallengeResponseAuthentication/ s/no/yes/' /etc/ssh/sshd_config
sed -i -e 's/#UsePAM/UsePAM/' -e '/UsePAM/ s/no/yes/' /etc/ssh/sshd_config
# sed -i -e '/#PasswordAuthentication/ a PasswordAuthentication no' /etc/ssh/sshd_config
sed -i -e 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
# Start/Restart the SSH service - example for Docker
pkill sshd
/usr/sbin/sshd -D &
EOF
chmod +x ./python/ssh_otp_update_sshd.sh

echo
yellow "This enables the keyboard-interactive authentication and PAM authentication modules. 
The password authentication is disabled."

dc exec python ./python/ssh_otp_update_sshd.sh
dc exec python diff /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# service sshd stop
# service sshd start
# sudo systemctl restart sshd

tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE POLICY FOR SSH - TEAM1 - VAMPIRES
#-------------------------------------------------------------------------------\n"

green "Create policy configuration for Vampires."
tee ./vault/config/tmp/vampires.hcl <<EOF
# To configure the SSH secrets engine
path "ssh/creds/vampires" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
EOF

green "Create policy from vampires.hcl"
pe "vault policy write vampires ./vault/config/tmp/vampires.hcl"


tput clear
cyan "#-------------------------------------------------------------------------------
# ENABLE USERS FOR TEAM1 - VAMPIRES
#-------------------------------------------------------------------------------\n"

green "Configure the auth backend for SSH OTP"
pe "vault auth enable userpass"
pe "vault write auth/userpass/users/bob password="password" policies=vampires"

# cyan "Authenticate as Bob the Vampire"
pe "vault login -token-only -method=userpass username=bob password=password"


tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE CREDENTIAL FOR SSH OTP
#-------------------------------------------------------------------------------\n"

cyan "Get the OTP for the client"
pe "vault write ssh/creds/vampires ip=10.1.10.1 | tee /tmp/otp.txt"
yellow "ip must match cidr defined in role cidr_list."
# pe "cat /tmp/otp.txt"
yellow "value for key is the ssh password"

echo
green "Run this: ssh root@localhost"
white "ssh root@localhost"
yellow "You can only use the password once...hence OTP"

# This alternative command requires sshpass; no to Mac by default
# pe "vault ssh -role=vampires -mode=otp -strict-host-key-checking=no vagrant@192.168.50.101"
