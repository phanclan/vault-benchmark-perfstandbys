#!/bin/bash
# set -e

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. demo-magic.sh -d -p -w ${DEMO_WAIT}

cyan "##########################################################################################
# Running: $0: Building Your Own Certificate
##########################################################################################"
echo
echo
green "# Steps
1. Store CA outside the Vault (air gapped)
2. Create CSRs for the intermediates
3. Sign CSR outside Vault and import intermediate
4. Issue leaf certificates from the Intermediate CA
"

cyan "
##########################################################################################
# Step 0: Start dev instance of Vault
##########################################################################################"
echo
# set +e
# pkill vault
# set -e

export VAULT_TOKEN=$(consul kv get service/vault/root-token)
export VAULT_ADDR=http://127.0.0.1:10101
# green "Start Vault dev"
# pe "vault server -dev -dev-root-token-id=$VAULT_TOKEN -dev-listen-address=0.0.0.0:8200 > /tmp/vault.log 2>&1 &"

green "Log in to vault"
pe "vault login $VAULT_TOKEN"

green "Enable audit device, so you can examine logs later"
pe "vault audit enable file file_path=/tmp/audit.log log_raw=true"

cyan "
##########################################################################################
# Step 1: Generate Root CA
##########################################################################################"
echo
green "Enable the PKI secret engine at the pki path"
pe "vault secrets enable pki"

green "Tune the pki engine to issue certificates with a maximum time-to-live (TTL) of 87600 hours."
pe "vault secrets tune -max-lease-ttl=2562000h pki"

green "Generate the root certificate and save the certificate in CA_cert.crt."
pe "vault write -field=certificate pki/root/generate/internal \
        common_name="example.com" \
        ttl=87600h > CA_cert.crt"

yellow "This generates a new self-signed CA certificate and private key. 
Vault will automatically revoke the generated root at the end of its lease period (TTL); 
the CA certificate will sign its own Certificate Revocation List (CRL)."
echo

green "Configure the CA and CRL URLs:"
pe 'vault write pki/config/urls \
    issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
    crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"'

yellow "NOTE: To examine the generated root certificate, you can use OpenSSL."

green "# Print the certificate in text form"
pe "openssl x509 -in CA_cert.crt -text"

green "# Print the validity dates"
pe "openssl x509 -in CA_cert.crt -noout -dates"

cyan "
##########################################################################################
# Step 2: Generate Intermediate CA
##########################################################################################"
echo
green "Enable the pki secrets engine at the pki_int path:"
pe "vault secrets enable -path=pki_int pki"

green "Tune the pki_int secrets engine to issue certificates with a maximum time-to-live (TTL) of 43800 hours."
pe "vault secrets tune -max-lease-ttl=43800h pki_int"

green "Execute the following command to generate an intermediate and save the CSR as pki_intermediate.csr:"
pe 'vault write -format=json pki_int/intermediate/generate/internal \
        common_name="example.com Intermediate Authority" \
        | jq -r ".data.csr" > pki_intermediate.csr'

green "Sign the intermediate certificate with the root certificate. 
Save the generated certificate as intermediate.cert.pem:"
pe 'vault write -format=json pki/root/sign-intermediate csr=@pki_intermediate.csr \
        format=pem_bundle ttl="43800h" \
        | jq -r ".data.certificate" > intermediate.cert.pem'

green "Once the CSR is signed and the root CA returns a certificate, it can be imported back into Vault:"
pe "vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem"

cyan "
###############################################################################
# Step 3: Create a Role
###############################################################################"

cyan "A role is a logical name that maps to a policy used to generate those credentials. 
It allows configuration parameters to control certificate common names, 
alternate names, the key uses that they are valid for, and more.

Here are a few noteworthy parameters:
${RED}allowed_domains${COLOR_RESET} - Specifies the domains of the role (used with allow_bare_domains and allow-subdomains options)
${RED}allow_bare_domains${COLOR_RESET} - Specifies if clients can request certificates matching the value of the actual domains themselves
${RED}allow_subdomains${COLOR_RESET} - Specifies if clients can request certificates with CNs that are subdomains of the CNs allowed by the other role options (NOTE: This includes wildcard subdomains.)
${RED}allow_glob_domains${COLOR_RESET} - Allows names specified in allowed_domains to contain glob patterns (e.g. ftp*.example.com)"

green "Create a role named example-dot-com which allows subdomains."
pe 'vault write pki_int/roles/example-dot-com \
        allowed_domains="example.com" \
        allow_subdomains=true \
        max_ttl="720h"'

cyan "
##########################################################################################
# Step 4: Request Certificates
##########################################################################################"

cyan "Keep certificate lifetimes short to align with Vault's philosophy of short-lived secrets."

green "Execute the following command to request a new certificate for the test.example.com domain based on the example-dot-com role:"
pe 'vault write pki_int/issue/example-dot-com common_name="test.example.com" ttl="24h" > /tmp/sample.pem'
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
