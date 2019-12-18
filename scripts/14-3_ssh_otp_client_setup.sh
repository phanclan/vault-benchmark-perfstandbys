#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# STOP: CONSOLIDATED TO 14-3_ssh_otp_server_setup.sh
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------








#!/usr/bin/env bash
. env.sh
# set -e

cyan "Confirm that you currently can't auto-login"
pe "ssh 192.168.50.150"

green "# Create ssh key pair"
pe "ssh-keygen -f /home/vagrant/.ssh/id_rsa -t rsa -N ''"

green "# Trust CA certificate in known_hosts"
pe "cat /vagrant/CA_certificate >> /home/vagrant/.ssh/known_hosts"
# pe "rm -f /vagrant/CA_certificate"

green "# Authenticate to Vault"
export VAULT_ADDR=http://192.168.50.150:8200
pe "vault login -method=userpass username=johnsmith password=test"


cyan "#-------------------------------------------------------------------------------
# CREATE SSH ROLE
#-------------------------------------------------------------------------------"
# cat << EOF
# cat /home/vagrant/.ssh/id_rsa.pub | vault write -format=json ssh-client-signer/sign/clientrole public_key=- | jq -r '.data.signed_key' > /home/vagrant/.ssh/id_rsa-cert.pub
# EOF
# p

# cat /home/vagrant/.ssh/id_rsa.pub | \
#   vault write -format=json ssh-client-signer/sign/clientrole public_key=- \
#   | jq -r '.data.signed_key' > /home/vagrant/.ssh/id_rsa-cert.pub

# chmod 0400 /home/vagrant/.ssh/id_rsa-cert.pub

vault write ssh/roles/otp_key_role \
    key_type=otp \
    default_user=root \
    cidr_list=0.0.0.0/0


cyan "## View enabled extension, principals, and metadata of the signed key."
pe "ssh-keygen -Lf ~/.ssh/id_rsa-cert.pub"

yellow "To use the new cert you can use the following command"
# yellow "ssh vault"
green "ssh 192.168.50.150"


cyan "#-------------------------------------------------------------------------------
# CREATE SSH ROLE
#-------------------------------------------------------------------------------"

export VAULT_ADDR=http://vaultserver:8200
wget https://releases.hashicorp.com/vault-ssh-helper/0.1.4/vault-ssh-helper_0.1.4_linux_amd64.zip
unzip vault-ssh-helper_0.1.4_linux_amd64.zip
chmod 0755 vault-ssh-helper
sudo mv vault-ssh-helper /usr/local/bin
rm vault-ssh-helper_0.1.4_linux_amd64.zip

vault-ssh-helper -dev -verify-only -config=/tmp/ssh-config.hcl




Download the vault-ssh-helper
$ wget https://releases.hashicorp.com/vault-ssh-helper/0.1.4/vault-ssh-helper_0.1.4_linux_amd64.zip

# Unzip the vault-ssh-helper in /user/local/bin
sudo unzip -q vault-ssh-helper_0.1.4_linux_amd64.zip -d /usr/local/bin




sudo mkdir -p /etc/vault-ssh-helper.d
export VAULT_ADDR=http://192.168.50.100

echo "Create vault-ssh-helper configuration"
sudo tee /etc/vault-ssh-helper.d/config.hcl <<EOF
vault_addr = "http://192.168.50.101:8200"
ssh_mount_point = "ssh"
tls_skip_verify = true
allowed_roles = "*"
allowed_cidr_list="0.0.0.0/0"
EOF

# cyan "
# ###############################################################################
# # Configure PAM
# ###############################################################################"
# echo "Update PAM sshd configuration"
# cp /etc/pam.d/sshd /etc/pam.d/sshd.bak
# # sudo cp /etc/pam.d/sshd.bak /etc/pam.d/sshd
# sed -i -e 's/@include common-auth/#@include common-auth/' -e '/#@include common-auth/ a \
# auth requisite pam_exec.so quiet expose_authtok log=/tmp/vaultssh.log /usr/local/bin/vault-ssh-helper -config=/etc/vault-ssh-helper.d/config.hcl -dev\
# auth optional pam_unix.so not_set_pass use_first_pass nodelay' /etc/pam.d/sshd
# # diff /etc/pam.d/sshd /etc/pam.d/sshd.bak

cyan "
###############################################################################
# Configure SSH
###############################################################################"

# echo "Update sshd configuration"
# green "Set the following three options:
# ChallengeResponseAuthentication yes
# PasswordAuthentication no 
# UsePAM yes"
# echo

# cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
# # sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
# sed -i -e '/ChallengeResponseAuthentication/ s/no/yes/' /etc/ssh/sshd_config
# sed -i -e 's/#UsePAM/UsePAM/' -e '/UsePAM/ s/no/yes/' /etc/ssh/sshd_config
# # sed -i -e '/#PasswordAuthentication/ a PasswordAuthentication no' /etc/ssh/sshd_config
# sed -i -e 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# # diff /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
# # service sshd stop
# # service sshd start
# sudo systemctl restart sshd