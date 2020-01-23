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
# Step 1: Generate Root CA
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

green "Generate the root CA certificate and private key. Save the certificate to CA_cert.crt."
pe "vault write -field=certificate pki_root/root/generate/internal \
    common_name="hashidemos.io" \
    ttl=175200h \
    key_bits=4096 > /tmp/CA_cert.crt"
# Info on Vault PKI options: https://www.vaultproject.io/api/secret/pki/index.html

yellow "This generates a new self-signed CA certificate and private key.
Vault will automatically revoke the generated root at the end of its lease period (TTL);
the CA certificate will sign its own Certificate Revocation List (CRL)."
echo

green "Verify that the certificate has been generated"
pe "curl $VAULT_ADDR/v1/pki_root/ca/pem"

green "#--> Configure the CA and Certificate Revocation List (CRL) URLs:"
pe 'vault write pki_root/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki_root/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki_root/crl"'

yellow "NOTE: To examine the generated root certificate, you can use OpenSSL."

green "# Print the certificate in text form"
pe "openssl x509 -in /tmp/CA_cert.crt -text"

green "# Print the validity dates"
pe "openssl x509 -in /tmp/CA_cert.crt -noout -dates"

cyan "#-------------------------------------------------------------------------------
# Step 2: GENERATE INTERMEDIATE CA
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

green "Tune the pki_int secrets engine to issue certificates with a maximum time-to-live (TTL) of 43800 hours."
pe "vault secrets tune -max-lease-ttl=43800h pki_int"

green "Generate an intermediate CSR. Save the CSR as pki_intermediate.csr"
pe 'vault write -format=json pki_int/intermediate/generate/internal \
        common_name="example.com Intermediate Authority" \
        | jq -r ".data.csr" > /tmp/pki_intermediate.csr'

green "Sign the intermediate CSR with the root certificate.
Save the generated certificate as intermediate.cert.pem:"
pe 'vault write -format=json pki_root/root/sign-intermediate csr=@pki_intermediate.csr \
        format=pem_bundle ttl="43800h" \
        | jq -r ".data.certificate" > /tmp/intermediate.cert.pem'

green "CSR is signed and root CA returned a certificate. Import Root signed cert into Intermediate CA"
pe "vault write pki_int/intermediate/set-signed certificate=@/tmp/intermediate.cert.pem"

green "Verify signing was successful"

pe "curl -s $VAULT_ADDR/v1/pki_int/ca/pem | openssl x509 -text"

green "Configure the CA and Certificate Revocation List (CRL) URLs:"
pe 'vault write pki_int/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki_int/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki_int/crl"'

cyan "
#-------------------------------------------------------------------------------
# Step 3: CREATE A ROLE
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

green "Create a role named example-dot-com which allows subdomains."
pe 'vault write pki_int/roles/example-dot-com \
    allowed_domains="example.com, hashidemos.io" \
    allow_subdomains=true \
    max_ttl="720h" \
    generate_lease=true
    '

cyan "
#-------------------------------------------------------------------------------
# Step 4: REQUEST CERTIFICATES USING ROLE
#-------------------------------------------------------------------------------\n"

cyan "Keep certificate lifetimes short to align with Vault's philosophy of short-lived secrets."

green "Execute the following command to request a new certificate for the test.example.com domain based on the example-dot-com role:"
pe 'vault write pki_int/issue/example-dot-com \
common_name="bastion-0.pphan.hashidemos.io" \
ttl="24h" > /tmp/sample.pem'
pe 'cat /tmp/sample.pem'

green "The response contains the PEM-encoded private key, key type and certificate serial number."

yellow "NOTE: A certificate can be renewed at any time by issuing a new certificate with the same CN.
The prior certificate will remain valid through its time-to-live value unless explicitly revoked."

cyan "
##########################################################################################
# Step 5: Revoke Certificates
##########################################################################################"

cyan "If a certificate must be revoked, you can easily perform the revocation
action which will cause the CRL to be regenerated. When the CRL is regenerated,
any expired certificates are removed from the CRL."

green "To revoke an issued certificate."
green "vault write pki_int/revoke serial_number=<serial_number>"
pe "vault write pki_int/revoke serial_number=$(grep serial /tmp/sample.pem | awk '{print $NF}')"

cyan "
###############################################################################
# Step 6: Remove Expired Certificates
###############################################################################"

cyan "Keep the storage backend and CRL by periodically removing certificates that
have expired and are past a certain buffer period beyond their expiration time."
echo

green "To remove revoked certificate and clean the CRL."
pe "vault write pki_int/tidy tidy_cert_store=true tidy_revoked_certs=true"


# Resources
# http://yet.org/2018/10/vault-pki/

mkdir -p /etc/consul-template.d/pki-demo.hcl && cd /etc/consul-template.d/pki-demo.hcl

tee pki-demo.hcl <<EOF

vault {
  address = "http://10.10.1.42:8200"
  renew_token = true

  retry {
    enabled = true
    attempts = 5
    backoff = "250ms"
  }
}

template {
  source      = "/etc/consul-template.d/yet-cert.tpl"
  destination = "/etc/nginx/certs/yet.crt"
  perms       = "0600"
  command     = "systemctl reload nginx"
}

template {
  source      = "/etc/consul-template.d/yet-key.tpl"
  destination = "/etc/nginx/certs/yet.key"
  perms       = "0600"
  command     = "systemctl reload nginx"
}
EOF

sudo tee /etc/consul-template.d/yet-cert.tpl << EOF
{{- /* yet-cert.tpl */ -}}
{{ with secret "pki_int/issue/example-dot-com" "common_name=bastion-0.pphan.hashidemos.io" "ttl=2m" }}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}{{ end }}
EOF

sudo tee /etc/consul-template.d/yet-key.tpl <<EOF

{{- /* yet-key.tpl */ -}}
{{ with secret "pki_int/issue/example-dot-com" "common_name=bastion-0.pphan.hashidemos.io" "ttl=2m"}}
{{ .Data.private_key }}{{ end }}
EOF

consul-template -config='/etc/consul-template.d/pki-demo.hcl'


tee /etc/nginx/sites-available/pki-demo <<EOF
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
    ssl_certificate     /etc/nginx/certs/yet.crt;
    ssl_certificate_key /etc/nginx/certs/yet.key;
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    location / {
      root   /usr/share/nginx/html;
      index  index.html index.htm;
    }
}
EOF

# Enable website
ln -s /etc/nginx/sites-available/pki-demo /etc/nginx/sites-enabled/pki-demo

# Remove default website
rm /etc/nginx/sites-enabled/default

