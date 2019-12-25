#!/bin/bash
# uncomment if running in directory parent to scripts
cd ./scripts
. env.sh
# set -e

cyan "Running: $0: Enable AWS Dynamic Secrets"
echo

# open https://phanclan.github.io/vault-benchmark-perfstandbys/slides/vault-aws.html

#-------------------------------------------------------------------------------
#--- This block allows us to start dev instance of vault if it is not running.
#-------------------------------------------------------------------------------
# if ! VAULT_ADDR=http://127.0.0.1:8200 vault status > /dev/null; then
# green "Start Vault dev"
# export VAULT_ADDR=http://127.0.0.1:8200
# export VAULT_TOKEN=root
# pe "vault server -dev -dev-root-token-id=$VAULT_TOKEN -dev-listen-address=0.0.0.0:8200 > /tmp/vault.log 2>&1 &"
# pe "vault login root"
# green "Enable audit device, so you can examine logs later"
# pe "vault audit enable file file_path=/tmp/audit.log log_raw=true"
# fi
#-------------------------------------------------------------------------------

tput clear
cyan "#-------------------------------------------------------------------------------
# ENABLE AWS DYNAMIC SECRETS
#-------------------------------------------------------------------------------\n"
echo

cyan "#-------------------------------------------------------------------------------
# CONFIGURE AWS ACCOUNT TO USE SECRETS
#-------------------------------------------------------------------------------\n"

green '
Go to IAM Management Console: https://console.aws.amazon.com/iam. 
Create a new User.   
Give it Programmatic Access only.
Select Attach existing policies directly.
Click Create policy.
Paste the policy below.
Name the policy "hashicorp-vault-lab"

Make sure to replace your <Account ID> in the Resource. 
When Vault dynamically creates the users, the username starts with the “vault-” prefix.

The account number can be found in AWS Support Dashboard:'

echo
green 'Sample Policy:\n'
white '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "iam:AttachUserPolicy",
                "iam:CreateAccessKey",
                "iam:CreateUser",
                "iam:DeleteAccessKey",
                "iam:DeleteUser",
                "iam:DeleteUserPolicy",
                "iam:DetachUserPolicy",
                "iam:ListAccessKeys",
                "iam:ListAttachedUserPolicies",
                "iam:ListGroupsForUser",
                "iam:ListUserPolicies",
                "iam:PutUserPolicy",
                "iam:RemoveUserFromGroup"
            ],
            "Resource": [
                "arn:aws:iam::<ACCOUNT_ID>:user/phan-vault-*"
                "arn:aws:iam::<ACCOUNT_ID>:group/*"
            ]
        }
    ]
}'
p "Press Enter to continue"

green "#-------------------------------------------------------------------------------
# ENABLE AWS DYNAMIC SECRETS ON VAULT
#-------------------------------------------------------------------------------"
# export VAULT_TOKEN=$(grep 'Initial Root Token:' /tmp/shamir-1.txt | awk '{print $NF}')
pe "vault secrets enable -path=aws aws"

echo
green "#--> Tune the default lease TTL for the AWS secrets engine to 2 minutes."
pe "vault secrets tune -default-lease-ttl=2m aws/"

green "#--> Configure the credentials used to communicate with AWS to generate the IAM credentials:"
yellow "Example configuration. Replace “access_key” and “secret_key” with your keys.\n"

white "vault write aws/config/root \\
    access_key=<ACCESS_KEY_ID> \\
    secret_key=<SECRET_ACCESS_KEY>
"
export ACCESS_KEY_ID=$(awk '/vault-lab/ && $0 != "" { getline ; print $NF}' ~/.aws/credentials)
export SECRET_ACCESS_KEY=$(awk '/vault-lab/ && $0 != "" { getline ; getline ; print $NF}' ~/.aws/credentials)

vault write aws/config/root \
    access_key=$ACCESS_KEY_ID \
    secret_key=$SECRET_ACCESS_KEY

echo
red "Even though the path above is aws/config/root, do not use your AWS root account credentials. 
Instead generate a dedicated user or role."
read

tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE VAULT AWS ROLE
#-------------------------------------------------------------------------------\n"

cyan 'Configure a Vault role that maps to a set of permissions in AWS as well as an AWS credential type. 
When users generate credentials, they are generated against this role. An example:'

white '
vault write aws/roles/phan-s3-ec2-all-role \
    policy_arns=arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess,arn:aws:iam::aws:policy/IAMReadOnlyAccess \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    }
  ]
}
EOF
'
echo
# p "Press Enter to continue"

vault write aws/roles/phan-s3-ec2-all-role \
    credential_type=iam_user \
    policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": "*"
    }
  ]
}
EOF
p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE A NEW SET OF CREDENTIALS
#-------------------------------------------------------------------------------\n"

cyan 'Generate a new credential by reading from the "/creds" endpoint with the name of the role:'
echo "How many AWS users do you want to create (enter a number):"
read AWSCREDS
rm /tmp/phan-s3-ec2-all-role.txt
for i in $(seq 1 $AWSCREDS); do
    vault read aws/creds/phan-s3-ec2-all-role | tee -a /tmp/phan-s3-ec2-all-role.txt
    echo ""
done

p "Press Enter to continue"
cat /tmp/phan-s3-ec2-all-role.txt

yellow 'Note the lease_id. You will need that value to revoke the credentials.'
echo
green 'Confirm user (vault-token-<role_name>-*) is created in AWS IAM.'
white 'https://console.aws.amazon.com/iam/home#/users'
echo
red 'IAM credentials are eventually consistent with respect to other Amazon services. 
If you are planning on using these credential in a pipeline, 
you may need to add a delay of 5-10 seconds (or more) after 
fetching credentials before they can be used successfully.'
p "Press Enter to continue"

# green "#--- Generate accounts from Performance Secondary"
# for i in {1..3}; do
#     vault2 read aws/creds/phan-s3-ec2-all-role | tee /tmp/phan-s3-ec2-all-role.txt
#     echo ""
# done
# p "Press Enter to continue"

tput clear
cyan "#-------------------------------------------------------------------------------
# Revoking the secret
#-------------------------------------------------------------------------------\n"

cyan 'What if these credentials were leaked? We can revoke the credentials.'
export AWS_LEASE_ID=$(grep "lease_id" /tmp/phan-s3-ec2-all-role.txt | awk '{print $NF}')
pe "echo $AWS_LEASE_ID"
pe "vault lease revoke $AWS_LEASE_ID"

yellow "The AWS IAM user account is no longer there"
echo
cyan 'What if all my credentials for a role were leaked? Revoke with a prefix.'
pe "vault lease revoke -prefix aws/creds/phan-s3-ec2-all-role"
p "Press Enter to continue"

tput clear
cyan "#------------------------------------------------------------------------------
# GENERATE A NEW SET OF DATABASE CREDENTIALS FOR USE VIA API
#------------------------------------------------------------------------------\n"
echo

green "#--> Create lease"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" -X PUT $VAULT_ADDR/v1/aws/creds/phan-s3-ec2-all-role | jq "." | tee /tmp/phan-s3-ec2-all-role.txt'
pe 'export LEASE_ID=$(jq -r ".lease_id" < /tmp/phan-s3-ec2-all-role.txt)'

green "#--> List leases"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" -X LIST $VAULT_ADDR/v1/sys/leases/lookup/aws/creds/phan-s3-ec2-all-role | jq "." '

echo
green "#--- Renew leases"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" -X PUT $VAULT_ADDR/v1/sys/leases/renew/$LEASE_ID | jq "."'

echo
green "#--- Revoke leases"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" -X PUT $VAULT_ADDR/v1/sys/leases/revoke/$LEASE_ID | jq "."'

echo ""
white "This concludes the AWS dynamic secrets engine component of the demo."
p "Press any key to return to menu..."

