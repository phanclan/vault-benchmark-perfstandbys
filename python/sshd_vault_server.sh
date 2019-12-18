curl -o /etc/ssh/trusted-user-ca-keys.pem http://vc1s1:8200/v1/ssh-client-signer/public_key
echo "TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem" | tee -a /etc/ssh/sshd_config
pkill sshd
/usr/sbin/sshd -D &
echo "Add users ubuntu and centos for later"
useradd ubuntu -p $(head /dev/urandom | tr -dc A-Za-z0-9 | head -c10) -m
useradd centos -p $(head /dev/urandom | tr -dc A-Za-z0-9 | head -c10) -m
# Need to create password for users, though we won't use it.
