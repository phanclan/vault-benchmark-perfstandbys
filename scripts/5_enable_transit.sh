. env.sh
# export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
export VAULT_TOKEN=$(consul kv get service/vault/root-token)
export VAULT_TOKEN=${VAULT_TOKEN:-'root'}
export VAULT_PORT=${VAULT_PORT:-10101}
export VAULT_ADDR=http://127.0.0.1:${VAULT_PORT}


tput clear
cyan "#------------------------------------------------------------------------------
# Running: $0: Enable/configure the Transit Secret Engine (Encryption as a Service)
#------------------------------------------------------------------------------\n"

cyan "Link: https://learn.hashicorp.com/vault/encryption-as-a-service/eaas-transit"
echo
white 'The transit secrets engine handles cryptographic functions on data in-transit. 
Vault does not store the data sent to the secrets engine. 
It can be viewed as "cryptography as a service" or "encryption as a service". 
The transit secrets engine can sign and verify data; 
generate hashes and HMACs of data; and act as a source of random bytes.

The primary use case for transit is to encrypt data from applications 
while still storing that encrypted data in some primary data store. 
This relieves the burden of proper encryption/decryption from 
application developers and pushes the burden onto the operators of Vault.'

# white 'Key derivation is supported, which allows the same key to be used for 
# multiple purposes by deriving a new key based on a user-supplied context value. 
# In this mode, convergent encryption can optionally be supported, 
# which allows the same input values to produce the same ciphertext.

# Datakey generation allows processes to request a high-entropy key 
# of a given bit length be returned to them, encrypted with the named key. 
# Normally this will also return the key in plaintext to allow for immediate use, 
# but this can be disabled to accommodate auditing requirements.'
echo

green "#--- Enable Transit Secret Engine"
pe "vault secrets enable -path=${TRANSIT_PATH} transit"

tput clear
cyan "#------------------------------------------------------------------------------
# CREATE THE ENCRYPTION KEY RING FOR USE
#------------------------------------------------------------------------------\n"

green "#--- Create a transit encryption key by the HR team to encrypt/decrypt data.\n"
white "COMMAND: vault write -f transit/keys/<name of key ring>"
pe "vault write -f ${TRANSIT_PATH}/keys/hr"

yellow "Usually, each application has its own encryption key."
p "Press Enter to continue"

tput clear
cyan "#------------------------------------------------------------------------------
# SEND DATA TO BE ENCRYPTED BY NEW KEY RING
#------------------------------------------------------------------------------\n"

cyan "Once your transit engine is enabled and a key ring created, any client with 
a valid token, and proper permission can send data to be encrypted by Vault. \n"
green 'Encrypt some plaintext data using the /encrypt endpoint with a named key:'
echo
white 'All plaintext data must be base64-encoded. Vault does not require that the plaintext be "text". 
It could be a binary file such as a PDF or image. The easiest safe transport mechanism for this data 
as part of a JSON payload is to base64-encode it.'
echo
yellow 'NOTE: Vault does not store any of this data. The caller is responsible for 
storing the encrypted ciphertext. When the caller wants the plaintext, it must 
provide the ciphertext back to Vault to decrypt the value.'
echo
# Vault HTTP API imposes a maximum request size of 32MB to prevent a denial of service attack. 
# This can be tuned per listener block in the Vault server configuration.'
white "COMMAND: vault write transit/encrypt/<name of key ring> plaintext=\$(base64 <<<\"<text to be encrypted>\")"

pe 'vault write transit-blog/encrypt/hr plaintext=$(base64 <<< "SSN 123-45-6789") | tee /tmp/ciphertext.txt'

p "Press Enter to continue"

tput clear
cyan "#------------------------------------------------------------------------------
# DECRYPT DATA
#------------------------------------------------------------------------------\n"

green 'Decrypt your data using the "/decrypt" endpoint with a named key. Then, decode base64'
white "COMMAND: vault write transit/decrypt/<name of key ring> ciphertext=\"<cipher text received from encrypting>\""
pe "vault write transit-blog/decrypt/hr ciphertext=$(grep cipher /tmp/ciphertext.txt | awk '{print $NF}') \
-format=json | tee /tmp/base64.txt"

green "The resulting data is base64-encoded (see the note above for details on why). Decode it to get the raw plaintext:"
pe "base64 --decode <<< $(jq -r .data.plaintext /tmp/base64.txt)"

cyan "Using ACLs, it is possible to restrict access to the transit secrets engine. 
Trusted operators can manage the named keys, but applications can only 
encrypt or decrypt using the named keys they need access to."
echo
p "Press Enter to continue"

tput clear
cyan "#------------------------------------------------------------------------------
# ROTATE THE ENCRYPTION KEY
#------------------------------------------------------------------------------\n"
cyan "This will generate a new encryption key and add it to the keyring for the named key:"
echo
green "Rotate the underlying encryption key. "
white "COMMAND: vault write -f <transit_path>/keys/<key_ring>/rotate"
pe "vault write -f transit-blog/keys/hr/rotate"

yellow "Future encryptions will use this new key. Old data can still be decrypted due to the use of a key ring."
echo
p "Press Enter to continue"

tput clear
green "#------------------------------------------------------------------------------
Upgrade already-encrypted data to a new key.
#------------------------------------------------------------------------------\n"

white 'Vault will decrypt the value using the appropriate key in the keyring and 
then encrypt the resulting plaintext with the newest key in the keyring.'
pe "vault write transit-blog/rewrap/hr ciphertext=$(grep cipher /tmp/ciphertext.txt | awk '{print $NF}') -format=json | tee /tmp/ciphertext2.txt"
p "Enter to continue"

yellow 'This process does not reveal the plaintext data. As such, a Vault policy 
could grant an untrusted process the ability to "rewrap" encrypted data, 
since the process would not be able to get access to the plaintext data.'
echo

green "##########################################################################################
# Verify"
pe "vault write transit-blog/decrypt/hr ciphertext=$(jq -r .data.ciphertext /tmp/ciphertext2.txt) | tee /tmp/base64-2.txt"
pe "base64 --decode <<< $(grep plain /tmp/base64-2.txt | awk '{print $NF}')"

green "Resources:
https://www.vaultproject.io/docs/secrets/transit/index.html"

