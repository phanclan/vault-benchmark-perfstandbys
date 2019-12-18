#!/bin/bash
# From vault guide
# set -e

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.

. demo-magic.sh -d -p -w ${DEMO_WAIT}

cyan "The Vault transit secret engine has a number of cryptographic capabilities. One of those is the ability to sign and verify cryptographic signatures.

This is useful when it is required to digitally prove that data of some sort was actually created by a specific entity. A common use case is during software distribution, such that an individual can confirm that software package has not been modified or corrupted in any way. Without verification, running unsigned code on a computer runs the risk of possibly executing malicious code.

This does rely on the recipient trusting that the owner's key is protected and has not been compromised, which is why it is very important that the private key remains private.

The process is as follows:

    The owner has data to be distributed, and signs it with their private key.
    The owner provides the data to a recipient. This might include making it available for download, or sending via email.
    The recipient then can verify the data with a public key, and confirm it was signed by the owner.

The following code block illustrates how this can be accomplished using Vault's Transit secret engine"
p

export TEST_HOME=/tmp
pe "vault server -dev -dev-root-token-id=root > $TEST_HOME/vault1.log 2>&1 &"
export VAULT_ADDR=http://127.0.0.1:8200

echo

tee /tmp/transit.hcl <<EOF
# Enable transit secrets engine
path "sys/mounts/transit" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# To read enabled secrets engines
path "sys/mounts" {
  capabilities = [ "read" ]
}

# Manage the transit secrets engine
path "transit/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
EOF
p

cyan "
###############################################################################
# Step 1: Enable Transit secret engine.
###############################################################################"

pe "vault secrets enable -path=transit transit"
# green "Success! Enabled the transit secrets engine at: transit/"

green "Create encryption key ring named 'orders'"
pe "vault write -f transit/keys/testkey type=rsa-4096"
# green "Success! Data written to: transit/keys/testkey"

cyan "
###############################################################################
# Step 2: Encrypt Secrets
###############################################################################"
pe "vault write transit/encrypt/testkey plaintext=$(base64 <<< '4111 1111 1111 1111') > /tmp/ciphertext.txt"
pe "CIPHER=$(grep cipher /tmp/ciphertext.txt | awk '{print $NF}')"

yellow "Vault does NOT store any data encrypted via the transit/encrypt endpoint. 
The output you received is the ciphertext. 
You can store this ciphertext at the desired location (e.g. MySQL database) or pass it to another application."

cyan "
###############################################################################
# Decrypt Ciphertext
###############################################################################"
pe "vault write transit/decrypt/testkey ciphertext=$CIPHER > /tmp/decoded.txt"
pe "DECODED=$(grep text /tmp/decoded.txt | awk '{print $NF}')"
pe "base64 --decode <<< $DECODED"

cyan "
###############################################################################
# Step 4: Rotate the Encryption Key
###############################################################################"
echo
green "To rotate the encryption key, invoke the transit/keys/<key_ring_name>/rotate endpoint."
pe "vault write -f transit/keys/testkey/rotate"

green "Encrypt another data."
green "vault write transit/encrypt/testkey plaintext=$(base64 <<< '4111 1111 1111 1111')"
pe "vault write transit/encrypt/testkey plaintext=$(base64 <<< '4111 1111 1111 1111') > /tmp/ciphertext2.txt"
pe "CIPHER2=$(grep text /tmp/ciphertext2.txt | awk '{print $NF}')"

green "Compare the ciphertexts from Step 2 as generated on your machine."
pe "CIPHER=$(grep cipher /tmp/ciphertext.txt | awk '{print $NF}')"

yellow 'Notice that the first ciphertext starts with "vault:v1:". After rotating the encryption key, the ciphertext starts with "vault:v2:". This indicates that the data is encrypted using the latest version of the key after the rotation.'
echo
green "Rewrap your cipertext from Step 2 with the latest version of the encryption key:"
pe "vault write transit/rewrap/testkey ciphertext=$CIPHER"

yellow 'Notice that the resulting ciphertext now starts with "vault:v2:".

This operation does not reveal the plaintext data. But Vault will decrypt the value using the appropriate key in the keyring and then encrypt the resulting plaintext with the newest key in the keyring.'

pe "vault read transit/keys/testkey"
# green "Key                       Value
# ---                       -----
# allow_plaintext_backup    false
# deletion_allowed          false
# derived                   false
# exportable                false
# keys                      map[1:map[name:rsa-4096 public_key:-----BEGIN PUBLIC KEY-----
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEApXjgKU3CgFnSj6wHGXAW
# aAF7gcdo7EHtoCGojB7Ukt7FpZ5RPOWBCgRtKUo3udVURhX4ZxGPYGYxn8O1LWd7
# lwTE6AMJmQd9DolTyUUO3cA1hOJuBp+V8qqbhJXm/b7pKtECN/mMy1PtvngdYNo6
# DA26ZbsvFTaqGcmMYeX9VY5vA+d9rBohQx++gO7ntJ+K3H0sztBjl+HSf9DmTQDy
# 5zPwY7ZZ8kS/DLAzj2/QuzpLe4J2Y0igiHJYcXFJryao+PiXh1FrXSyuMESKNcpS
# 4Ks3oU1Om/O6XpS0/7ho+MuNjR8BeDe+DBOaaejepEBbN6gbvHmWyQhAe+9OBzu3
# cNz08CDq8bjFlVzZWzh4gMAZPsqwYLcSgObj5gcCodiq5LoyP04GzO2QYs+3CEpy
# CB1m69YlrwRYJvi09S/edhvKVCij8ULW0AYvfTj7CEAw1QsIdPw1y3hxmVZqM467
# 7G7KEZlB7AldzJf6ck7lVAjzNisPC/A1mcZZhPX4BzxdQayKms4efeq1K6ghu0qt
# K93WO0khvNfA/bnas3o0QiYO5/jgUCD99VAa7Y1KkGY9SKJ4EJGD9mG1A/vggsDO
# 44Jw9nX0eQIlslwIlSHaHAP+M/2qvUsYcV+D9jW35edwPHxxcpPTTZyblhw9uw8J
# FFwZqR8gfk3ySVNc3GXFKWMCAwEAAQ==
# -----END PUBLIC KEY-----
#  creation_time:2018-04-11T17:50:17.476592091-05:00]]
# latest_version            1
# min_decryption_version    1
# min_encryption_version    0
# name                      testkey
# supports_decryption       true
# supports_derivation       false
# supports_encryption       true
# supports_signing          true
# type                      rsa-4096"

####  Signing Data ####
### syntax to sign is as follows
# vault write transit/sign/testkey \
#   input="<base64 encoded data>"

pe "echo 'this is my plaintext entry' | base64 | vault write transit/sign/testkey input=- > /tmp/signature.txt"
pe "cat /tmp/signature.txt"
# cyan "Key          Value
# ---          -----
# signature    vault:v1:B9OAYg+rnrtDGKqpBzj682ZIFW8Zp0w2vIdFZezjV4786XvTIjf5WDkKqzx7+vxOBh431N8rZTPMlp1f5mxlQkLISqEBc4l129UAjn3VBm2F9QIfpKe8gktqV+m8ZbN8zB9DBACNMlWagQ8RGawtDhPZ6sarWGij8YvQsrxdKiPI8nDE6my5Fw2cvmgEYoWclUK78jrgGznO+nDU3d7ZjNeCsv1XUzHdFmhao4WDEuxr1QUkhePIb/9KHY63IWAJks55+UfAR6YoBW8PKgUZtNiz7ptFEluMmQ/eC4gsKAJ/h59g2lJf0IqpD7SfDVtP6U+MuBOuN1j5M4E4T+WKo9pp5jilwAAl5l6xVKIwghcUxVY6ynsJXi3Fchm82ICbJmGqHEv6BfKbDdYd2BXaQ4U31TEKOR2gA4e8n+W/OujHdzPmo2PQv+GZrj+TDtwAM31nLJVeViUKTOrUoGbfsSY117/H5Y1KrDu5TzWZ/b3Rm7UOG53mDOZUzxJTmuY3xvVwUKKvrjwuEI8KhAixa77ZWcZRQs2Oy5DKlEx0PotfhlliNvDTkYVQUwxWO/Z6ipkWvPzuvHK/UsIZcm8yb435+snj3GgdNJge+zUvZkV5vvSZ18S/Hp7uMjMIzZSH7OgCf2DbTP36SCQGNy4rIC9uzT2O1JoXv8ChmSdpI+g="

cyan '
###############################################################################
####  Verifying Data ####
###   syntax to verify is as follows
# vault write transit/verify/testkey \
#   signature="<signature>" \
#   input="<base64 encoded data>"'

pe "echo 'this is my plaintext entry' | base64 | vault write transit/verify/testkey signature=$(grep sig /tmp/signature.txt | awk '{print $NF}') input=-"
# echo "this is my plaintext entry" | base64 | vault write transit/verify/testkey signature="vault:v1:B9OAYg+rnrtDGKqpBzj682ZIFW8Zp0w2vIdFZezjV4786XvTIjf5WDkKqzx7+vxOBh431N8rZTPMlp1f5mxlQkLISqEBc4l129UAjn3VBm2F9QIfpKe8gktqV+m8ZbN8zB9DBACNMlWagQ8RGawtDhPZ6sarWGij8YvQsrxdKiPI8nDE6my5Fw2cvmgEYoWclUK78jrgGznO+nDU3d7ZjNeCsv1XUzHdFmhao4WDEuxr1QUkhePIb/9KHY63IWAJks55+UfAR6YoBW8PKgUZtNiz7ptFEluMmQ/eC4gsKAJ/h59g2lJf0IqpD7SfDVtP6U+MuBOuN1j5M4E4T+WKo9pp5jilwAAl5l6xVKIwghcUxVY6ynsJXi3Fchm82ICbJmGqHEv6BfKbDdYd2BXaQ4U31TEKOR2gA4e8n+W/OujHdzPmo2PQv+GZrj+TDtwAM31nLJVeViUKTOrUoGbfsSY117/H5Y1KrDu5TzWZ/b3Rm7UOG53mDOZUzxJTmuY3xvVwUKKvrjwuEI8KhAixa77ZWcZRQs2Oy5DKlEx0PotfhlliNvDTkYVQUwxWO/Z6ipkWvPzuvHK/UsIZcm8yb435+snj3GgdNJge+zUvZkV5vvSZ18S/Hp7uMjMIzZSH7OgCf2DbTP36SCQGNy4rIC9uzT2O1JoXv8ChmSdpI+g=" input=-
green "Sample Output:
Key      Value
---      -----
valid    true"

pe "echo 'this is my MODIFIED plaintext entry' | base64 | vault write transit/verify/testkey signature=$(grep sig /tmp/signature.txt | awk '{print $NF}') input=-"

# echo "this is my MODIFIED plaintext entry" | base64 | vault write transit/verify/testkey signature="vault:v1:B9OAYg+rnrtDGKqpBzj682ZIFW8Zp0w2vIdFZezjV4786XvTIjf5WDkKqzx7+vxOBh431N8rZTPMlp1f5mxlQkLISqEBc4l129UAjn3VBm2F9QIfpKe8gktqV+m8ZbN8zB9DBACNMlWagQ8RGawtDhPZ6sarWGij8YvQsrxdKiPI8nDE6my5Fw2cvmgEYoWclUK78jrgGznO+nDU3d7ZjNeCsv1XUzHdFmhao4WDEuxr1QUkhePIb/9KHY63IWAJks55+UfAR6YoBW8PKgUZtNiz7ptFEluMmQ/eC4gsKAJ/h59g2lJf0IqpD7SfDVtP6U+MuBOuN1j5M4E4T+WKo9pp5jilwAAl5l6xVKIwghcUxVY6ynsJXi3Fchm82ICbJmGqHEv6BfKbDdYd2BXaQ4U31TEKOR2gA4e8n+W/OujHdzPmo2PQv+GZrj+TDtwAM31nLJVeViUKTOrUoGbfsSY117/H5Y1KrDu5TzWZ/b3Rm7UOG53mDOZUzxJTmuY3xvVwUKKvrjwuEI8KhAixa77ZWcZRQs2Oy5DKlEx0PotfhlliNvDTkYVQUwxWO/Z6ipkWvPzuvHK/UsIZcm8yb435+snj3GgdNJge+zUvZkV5vvSZ18S/Hp7uMjMIzZSH7OgCf2DbTP36SCQGNy4rIC9uzT2O1JoXv8ChmSdpI+g=" input=-

green "Sample Output:
Key      Value
---      -----
valid    false"
echo

###############################################################################
cyan "# Test with bad signature"
echo
pe 'echo "this is my plaintext entry" | base64 | vault write transit/verify/testkey signature="vault:v1:CORRUPTED_SIGNATURE" input=-'
green "Sample Output:
Error writing data to transit/verify/testkey: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/transit/verify/testkey
Code: 400. Errors:

* invalid base64 signature value"
echo

###############################################################################
cyan "# Test with mismatched signature"

pe "echo 'this is my plaintext entry NUMBER 2' | base64 | vault write transit/sign/testkey input=- > /tmp/signature2.txt && cat /tmp/signature2.txt"

# green "Sample Output:
# Key          Value
# ---          -----
# signature    vault:v1:icyiqwJofQVgd+7Tyfl5DBTKHTb2VaT/FBV5dqjqtfb5gJlU5W/RD6S5fcY9M3xTLpM2Nbh1s7JCC8JCcOZ/rlfNU6RDuGIKJIWvS7bjwF8s6hw9/eZGiLmM9oEo0/T9oTw0ef+c2JzKojc9i1auluK54cyw9HxmsdwkpT9WV1fl3yIm0jIWIZcyOPxiLtwRm8eyanYiIDm3M/CAWzy/RTNk6DIsPbK/oJVWcxXFZX5NqKdSPKhRThXkGk2B2LUVt1hCsyKYoSjVqHWyvb7kBYfy/lpG71s8CwTf+tslzSeuvcUrC3HvBsQ3nvPy8oSN1DEFAyMR2gwunfzYMDICYU3y6DNyOqAxA43ZEVqikqKgu5pt4YPsnbFcmqz8dcldKV5KPoqduvuRtksbaTmLoKO7x05t2BeaTYlrk2Q0nNDqLCZ4UlY5N0TpqERZRjmhL3YJ8zmF6yk/Gg+Q9UOa8kfZCaoEu9ncmT6nfD+tN0PBQoEEjTDhwYNak4wI40DG8doeDqjFsv93ZXtaJweRDOemU1C3e2JrrMrQAA2BOs+k8svS6Tqoj+leWSlkEnukOG7hA7Fq8RQHb5VPk/971wksTW0sje72Q+i6fTr1zI+8XZ021I0fgwtkhj7s+jLKA3suSU4D03LV9uQZv3rlg3jUtjbwVXgWkYDzIFTYpbQ="


green "####   Validate mismatched signature returns false"
echo
pe "echo 'this is my plaintext entry' | base64 | vault write transit/verify/testkey signature=$(grep sig /tmp/signature.txt | awk '{print $NF}') input=-"
green "Sample Output:
Key      Value
---      -----
valid    false"
echo

yellow "COMPLETE"
green "https://learn.hashicorp.com/vault/encryption-as-a-service/eaas-transit"