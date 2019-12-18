#!/bin/bash
sed -i -e 's/@include common-auth/#@include common-auth/' /etc/pam.d/sshd
# sed -i -e '/#@include common-auth/ a \
echo "auth requisite pam_exec.so quiet expose_authtok log=/tmp/vaultssh.log /usr/local/bin/vault-ssh-helper -config=/etc/vault-ssh-helper.d/config.hcl -dev" >> /etc/pam.d/sshd
echo "auth optional pam_unix.so not_set_pass use_first_pass nodelay" >> /etc/pam.d/sshd
