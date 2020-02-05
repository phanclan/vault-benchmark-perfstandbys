#!/bin/bash
cd ./scripts
. env.sh
cd -
# set -e

cyan "#-------------------------------------------------------------------------------
# Running: $0: Building Your Own Certificate
#-------------------------------------------------------------------------------\n"
echo
echo
green "# Steps
1. Store CA outside the Vault (air gapped)
2. Create CSRs for the intermediates
3. Sign CSR outside Vault and import intermediate
4. Issue leaf certificates from the Intermediate CA
"

cyan "#-------------------------------------------------------------------------------
# Step 0: Start dev instance of Vault
#-------------------------------------------------------------------------------\n"
#--> This section is for local dev instance.

# set +e
# pkill vault
# set -e

# green "Start Vault dev"
# pe "vault server -dev -dev-root-token-id=$VAULT_TOKEN -dev-listen-address=0.0.0.0:8200 > /tmp/vault.log 2>&1 &"

cyan "#-------------------------------------------------------------------------------
# Step 1: CREATE ROOT CA
#-------------------------------------------------------------------------------\n"
echo "#--> Log in to vault"
vault login $VAULT_TOKEN

echo "#--> Enable audit device, so you can examine logs later"
# pe "vault audit enable file file_path=/tmp/audit.log log_raw=true"

green "Enable the PKI secret engine and mount at the pki path"
pe "vault secrets enable -path=pki_root pki"

green "Tune the pki engine to issue certificates with a maximum time-to-live (TTL) of 87600 hours (10 years)."
pe "vault secrets tune -max-lease-ttl=2562000h pki"
# 2562000h is the max

green "#--> Generate Root CA Certificate and private Key. Save Certificate to CA_cert.crt."
pe "vault write -field=certificate pki_root/root/generate/internal \
    common_name="hashidemos.io" \
    ttl=175200h \
    key_bits=4096 > /tmp/CA_cert.crt"

# Info on Vault PKI options: https://www.vaultproject.io/api/secret/pki/index.html

yellow "You generated a new self-signed CA certificate and private key.
Vault will automatically revoke the generated root at the end of its lease period (TTL);
The CA certificate will sign its own Certificate Revocation List (CRL)."

echo
green "#--> Verify that the Certificate has been generated"
pe "curl -s $VAULT_ADDR/v1/pki_root/ca/pem"

green "# Print the certificate in text form"
pe "openssl x509 -in /tmp/CA_cert.crt -text"

green "# Print the validity dates"
pe "openssl x509 -in /tmp/CA_cert.crt -noout -dates"

cyan "#-------------------------------------------------------------------------------
# CONFIGURE CERTIFICATE REVOCATION FOR ROOT CA
#-------------------------------------------------------------------------------\n"

green "#--> Configure the CA and Certificate Revocation List (CRL) URLs:"
pe 'vault write pki_root/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki_root/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki_root/crl"'

yellow "NOTE: To examine the generated root certificate, you can use OpenSSL."

cyan "#-------------------------------------------------------------------------------
# STEP 2: CREATE INTERMEDIATE CA
#-------------------------------------------------------------------------------\n"
cyan "Following steps must be followed in order to generate an intermediate CA:

- Mount PKI to a new path
- Generate intermediate certificate signing request (CSR)
- Sign Intermediate CSR using Root CA and generate Certificate
- Import Root signed certificate into Intermediate CA
- Verify signing was successful
- Configure certificate revocation"

echo
green "#--> Enable the pki secrets engine at the pki_int path:"
pe "vault secrets enable -path=pki_int pki"

green "#--> Tune pki_int to issue certificates with a max time-to-live (TTL) of 43800 hours."
pe "vault secrets tune -max-lease-ttl=43800h pki_int"

green "#--> Generate Intermediate CSR. Save CSR as pki_intermediate.csr"
pe 'vault write -format=json pki_int/intermediate/generate/internal \
    common_name="hashidemos.io Intermediate Authority" \
    | jq -r ".data.csr" > /tmp/pki_intermediate.csr'

green "#--> Sign the intermediate CSR with the root certificate.
Save generated certificate as intermediate.cert.pem:"
pe 'vault write -format=json pki_root/root/sign-intermediate \
    csr=@/tmp/pki_intermediate.csr \
    format=pem_bundle \
    ttl="43800h" \
    | jq -r ".data.certificate" > /tmp/intermediate.cert.pem'

green "#--> Import Root signed cert into Intermediate CA."
# CSR is signed and root CA returned a certificate.
pe "vault write pki_int/intermediate/set-signed \
    certificate=@/tmp/intermediate.cert.pem"

green "Verify signing was successful"

pe "curl -s $VAULT_ADDR/v1/pki_int/ca/pem | openssl x509 -text | grep -B1 Issuers"

yellow "Should see root CA as issuer"
echo "
            Authority Information Access:
                CA Issuers - URI:http://127.0.0.1:8200/v1/pki_root/ca
"

echo
green "#--> Configure the CA and Certificate Revocation List (CRL) URLs:"
pe 'vault write pki_int/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki_int/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki_int/crl"'


cyan "#-------------------------------------------------------------------------------
# STEP 3: CREATE A ROLE
#-------------------------------------------------------------------------------\n"

cyan "A role is a logical name that maps to a policy used to generate those credentials.
It allows configuration parameters to control certificate common names,
alternate names, the key uses that they are valid for, and more.

Here are a few noteworthy parameters:
${RED}allowed_domains${COLOR_RESET} - Specifies the domains of the role (used with allow_bare_domains and allow-subdomains options)
${RED}allow_bare_domains${COLOR_RESET} - Specifies if clients can request certificates matching the value of the actual domains themselves
${RED}allow_subdomains${COLOR_RESET} - Specifies if clients can request certificates with CNs that are subdomains of the CNs allowed by the other role options
(NOTE: This includes wildcard subdomains.)
${RED}allow_glob_domains${COLOR_RESET} - Allows names specified in allowed_domains to contain glob patterns (e.g. ftp*.example.com)
More info: https://www.vaultproject.io/api/secret/pki/index.html#create-update-role
"

green "#--> Create a role named hashidemos which allows subdomains."
pe 'vault write pki_int/roles/hashidemos \
    allowed_domains="example.com, hashidemos.io" \
    allow_subdomains=true \
    max_ttl="720h" \
    generate_lease=true
    '
# `allowed_domains` restricts common name cert can be issued for.
# More info: https://www.vaultproject.io/api/secret/pki/index.html#create-update-role

cyan "#-------------------------------------------------------------------------------
# STEP 4: REQUEST CERTIFICATES USING ROLE
#-------------------------------------------------------------------------------\n"

cyan "Keep certificate lifetimes short. Recommended"

green "#--> Request a new certificate for the pphan.hashidemos.io domain based on the hashidemos role:"
pe 'vault write pki_int/issue/hashidemos \
    common_name="bastion-0.pphan.hashidemos.io" \
    ttl="24h" > /tmp/sample.pem'

pe 'cat /tmp/sample.pem'

# This is alternate method I am testing.
vault write -format=json pki_int/issue/hashidemos \
    common_name="bastion-0.pphan.hashidemos.io" ttl=24h | tee \
    >(jq -r ".data.certificate,.data.issuing_ca" > /tmp/ssl_crt) \
    >(jq -r ".data.private_key" > /tmp/key)

green "The response contains the PEM-encoded private key, key type and certificate serial number."

yellow "NOTE: A certificate can be renewed at any time by issuing a new certificate with the same CN.
The prior certificate will remain valid through its time-to-live value unless explicitly revoked."

cyan "#-------------------------------------------------------------------------------
# STEP 5: Revoke Certificates
#-------------------------------------------------------------------------------\n"

cyan "If a certificate must be revoked, you can easily perform the revocation
action which will cause the CRL to be regenerated. When the CRL is regenerated,
any expired certificates are removed from the CRL."

green "To revoke an issued certificate."
green "vault write pki_int/revoke serial_number=<serial_number>"
pe "vault write pki_int/revoke serial_number=$(grep serial /tmp/sample.pem | awk '{print $NF}')"

cyan "
#-------------------------------------------------------------------------------
# Step 6: Remove Expired Certificates
#-------------------------------------------------------------------------------\n"

cyan "Keep the storage backend and CRL by periodically removing certificates that
have expired and are past a certain buffer period beyond their expiration time."
echo

green "To remove revoked certificate and clean the CRL."
pe "vault write pki_int/tidy tidy_cert_store=true tidy_revoked_certs=true"

#-------------------------------------------------------------------------------
# RESOURCES
#
# http://yet.org/2018/10/vault-pki/
# https://medium.com/hashicorp-engineering/pki-as-a-service-with-hashicorp-vault-a8d075ece9a
#
#-------------------------------------------------------------------------------


#-------------------------------------------------------------------------------
# CONSUL-TEMPLATE
#-------------------------------------------------------------------------------

# --> Create folders on web server for Consul templates and PKI certs.
ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo mkdir -p -m 777 /etc/consul-template.d/ /etc/nginx/certs"

# --> Create Consul Template configuration
cat <<EOF | ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo cat > /etc/consul-template.d/pki-demo.hcl"
vault {
  address = "http://10.10.1.64:8200"
  token = "$(consul kv get service/vault/root-token)"
  renew_token = false

  retry {
    enabled = true
    attempts = 5
    backoff = "250ms"
  }
}

template {
  source      = "/etc/consul-template.d/yet-cert.tpl"
  destination = "/etc/nginx/cert/ssl_crt"
  perms       = "0600"
  command     = "systemctl reload nginx"
}

template {
  source      = "/etc/consul-template.d/yet-key.tpl"
  destination = "/etc/nginx/cert/key"
  perms       = "0600"
  command     = "systemctl reload nginx"
}
EOF
# Replace address and token with your own!!!
# We are not renewing the token in this demo.

# Was creating file and then scp. Now, sending it in one command.
# scp /tmp/pki-demo.hcl ubuntu@bastion-0.pphan.hashidemos.io:/etc/consul-template.d/

#-------------------------------------------------------------------------------
# CREATE TEMPLATES
#-------------------------------------------------------------------------------

# yet-cert.tpl and yet-key.tpl will be used by consul-template to generate NGINX TLS stuff.

cat <<EOF | ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo cat > /etc/consul-template.d/yet-cert.tpl"
{{- /* yet-cert.tpl */ -}}
{{ with secret "pki_int/issue/hashidemos" "common_name=bastion-0.pphan.hashidemos.io" "ttl=2m" }}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}{{ end }}
EOF

cat <<EOF | ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo cat > /etc/consul-template.d/yet-key.tpl"
{{- /* yet-key.tpl */ -}}
{{ with secret "pki_int/issue/hashidemos" "common_name=bastion-0.pphan.hashidemos.io" "ttl=2m"}}
{{ .Data.private_key }}{{ end }}
EOF

# Replace common_name with your own.

#-------------------------------------------------------------------------------
# SYSTEMD CONFIGURATION
#-------------------------------------------------------------------------------

#--> Create consul-template systemd configuration
tee /tmp/consul-template.service <<EOF
[Unit]
Description=consul-template
Requires=network-online.target
After=network-online.target

[Service]
EnvironmentFile=-/etc/sysconfig/consul-template
Restart=on-failure
ExecStart=/usr/local/bin/consul-template $OPTIONS -config='/etc/consul-template.d/pki-demo.hcl'
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

#--> Copy files to webserver
cat /tmp/consul-template.service | ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo tee /etc/systemd/system/consul-template.service"

#--> Start Consul Template service.
# ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo consul-template -config='/etc/consul-template.d/pki-demo.hcl'"
ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo systemctl start consul-template.service"

#--> Verify if service is running.
ssh ubuntu@bastion-0.pphan.hashidemos.io "systemctl status consul-template.service; journalctl -u consul-template.service -xe"

cyan "#-------------------------------------------------------------------------------
# STEP: CONFIGURE NGINX
#-------------------------------------------------------------------------------\n"

#--> Build configuration for nginx demo site
tee /tmp/pki-demo-site <<"EOF"
# redirect traffic from http to https.
server {
listen              80;
listen              [::]:80;
server_name         bastion-0.pphan.hashidemos.io www.bastion-0.pphan.hashidemos.io;
return 301          https://bastion-0.pphan.hashidemos.io$request_uri;
return 301          https://www.bastion-0.pphan.hashidemos.io$request_uri;
}

server {
    listen              443 ssl http2 default_server;
    server_name         bastion-0.pphan.hashidemos.io www.bastion-0.pphan.hashidemos.io;
    ssl_certificate     /etc/nginx/cert/ssl_crt;
    ssl_certificate_key /etc/nginx/cert/key;
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    location / {
      root   /usr/share/nginx/html;
      index  index.html index.htm;
    }
}
EOF

# WARNING: When copy/pasting the above text into zsh, it inserts "\" after $request_uri.
# Had to switch to bash.

cat /tmp/pki-demo-site | ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo tee /etc/nginx/sites-available/pki-demo"

# Don't need the next few lines. We will use consul-template to generate certs.
# scp /tmp/ssl_crt ubuntu@bastion-0.pphan.hashidemos.io:/etc/nginx/cert/
# scp /tmp/key ubuntu@bastion-0.pphan.hashidemos.io:/etc/nginx/cert/

# Enable website
ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo ln -s /etc/nginx/sites-available/pki-demo /etc/nginx/sites-enabled/pki-demo"

# Remove default website
ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo rm /etc/nginx/sites-enabled/default"

#-------------------------------------------------------------------------------
# Importing Issuing CA Root to Chrome
#-------------------------------------------------------------------------------
# Review Root CA pem
# curl -s $VAULT_ADDR/v1/pki_root/ca/pem | openssl x509 -text

# Download Root CA cert
curl -s $VAULT_ADDR/v1/pki_root/ca/pem > /tmp/pki_ca.pem

# Double click on pki_ca.pem from Finder (mac).
# Select System for Keychain. Click Add.
# Trust the certificate. When using this certificate: Always Trust

# Firefox
# Go to Preferences > Privacy & Security > Certificates
# Click "View Certificates" > Authorities > Import.
# Select your pem file. Click Open.
# Select Trust this CA to identify websites. Click OK.

#-------------------------------------------------------------------------------
# VERIFICATION
#-------------------------------------------------------------------------------

#--> From first terminal: NGINX Server
ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo systemctl stop consul-template.service"

#--> From second terminal: Watch certs increase every two minutes
watch vault list pki_int/certs

#--> From third terminal: Check NGINX certificate status
watch -n 5 "curl --cacert /tmp/pki_ca.pem  --insecure -v \
    https://bastion-0.pphan.hashidemos.io 2>&1 \
    | awk 'BEGIN { cert=0 } /^\* SSL connection/ { cert=1 } /^\*/ { if (cert) print }'"

# Replace /tmp/pki_ca.pem and https://bastion-0.pphan.hashidemos.io with your own

### Sample Output
echo "*  SSL certificate verify result: certificate has expired (10), continui
ng anyway."

#-------------------------------------------------------------------------------
# CERTIFICATE RENEWAL
#-------------------------------------------------------------------------------
#--> From first terminal: NGINX Server
ssh ubuntu@bastion-0.pphan.hashidemos.io "sudo systemctl start consul-template.service"

### Desired Output - from third terminal
echo "*  SSL certificate verify ok."

#-------------------------------------------------------------------------------
# CERTIFICATE REVOCATION
#-------------------------------------------------------------------------------

echo "#--> From terminal 3: Stop current watch command."

echo "#--> From terminal 3: Run this"
export CONSUL_HTTP_ADDR=http://consul.pphan.hashidemos.io:8500
export VAULT_ADDR=http://vault-0.pphan.hashidemos.io:8200
watch "curl -sS $VAULT_ADDR/v1/pki_int/crl | openssl crl -inform DER -text -noout -"

for i in $(vault list pki_int/certs); do
vault write pki_int/revoke serial_number="$i"
done