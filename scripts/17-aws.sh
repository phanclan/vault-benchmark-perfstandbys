#!/bin/bash
# uncomment if running in directory parent to scripts
# cd ./scripts
set -e
echo "#==> Source environment"
. env.sh

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

# tput clear
cyan "#-------------------------------------------------------------------------------
# ENABLE AWS DYNAMIC SECRETS
#-------------------------------------------------------------------------------\n"
echo

cyan "#-------------------------------------------------------------------------------
# CONFIGURE AWS ACCOUNT TO USE SECRETS
#-------------------------------------------------------------------------------"

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
green "#==> Enable AWS secrets engine."
pe "vault secrets enable -path=aws aws || true"

echo
green "#==> Tune the default lease TTL for the AWS secrets engine to 5 minutes."
pe "vault write aws/config/lease lease=5m lease_max=10m"
pe "vault secrets tune -default-lease-ttl=2m aws/"

green "#==> Configure the credentials used with AWS to generate the IAM credentials:"
echo
yellow 'Example: Replace "ACCESS_KEY_ID" and "SECRET_ACCESS_KEY" with your keys.\n'

white "vault write aws/config/root \\
    access_key=<ACCESS_KEY_ID> \\
    secret_key=<SECRET_ACCESS_KEY>
"
export ACCESS_KEY_ID=$(awk '/vault-lab/ && $0 != "" { getline ; print $NF}' ~/.aws/credentials)
export SECRET_ACCESS_KEY=$(awk '/vault-lab/ && $0 != "" { getline ; getline ; print $NF}' ~/.aws/credentials)

vault write aws/config/root \
    access_key=$ACCESS_KEY_ID \
    secret_key=$SECRET_ACCESS_KEY > /dev/null

echo
red "Even though the path above is 'aws/config/root', do not use your AWS root account credentials.
Instead, generate a dedicated user or role."

p "Press Enter to continue"

# tput clear
cyan "#-------------------------------------------------------------------------------
# CREATE VAULT AWS ROLE
#-------------------------------------------------------------------------------\n"

cyan 'Vault roles map to a set of permissions in AWS as well as an AWS credential type.
When users generate credentials, they are generated against this role.

An example:'

green "#==> Configure a Vault role"
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
# GENERATE A NEW SET OF AWS CREDENTIALS
#-------------------------------------------------------------------------------\n"

cyan '#==> Generate new AWS credential(s). Reference "/creds" endpoint. Specify the name of the role:\n'
echo "How many AWS users do you want to create (enter a number):"
read AWSCREDS
FILE=/tmp/phan-s3-ec2-all-role.txt
if test -f $FILE; then rm $FILE; fi
for i in $(seq 1 $AWSCREDS); do
    vault read aws/creds/phan-s3-ec2-all-role | tee -a /tmp/phan-s3-ec2-all-role.txt
    echo ""
done

p "Press Enter to continue"

# [pp - already displayed abovee with tee]
# green '#==> Display the created credentials.'
# cat /tmp/phan-s3-ec2-all-role.txt

echo
yellow 'Note the "lease_id". You will need that value to revoke the credentials.'
echo
green '#==> Confirm user (vault-token-<role_name>-*) is created in AWS IAM.'
white 'https://console.aws.amazon.com/iam/home#/users'
echo
green "#==> List users in your AWS account matching your role."
echo "aws iam list-users --output text | grep s3-ec2 | awk '{print \$2, \$5, \$6}'"
aws iam list-users --output text | grep s3-ec2 | awk '{print $2, $5, $6}'
echo
yellow 'AWS IAM credentials are eventually consistent.
If you are planning on using these credential in a pipeline,
you may need to add a delay of 5-10 seconds (or more) after
fetching credentials before they can be used successfully.'

echo
green "#==> See all of the active leases for your role."
pe "vault list sys/leases/lookup/aws/creds/phan-s3-ec2-all-role"


p "Press Enter to continue"

# green "#--- Generate accounts from Performance Secondary"
# for i in {1..3}; do
#     vault2 read aws/creds/phan-s3-ec2-all-role | tee /tmp/phan-s3-ec2-all-role.txt
#     echo ""
# done
# p "Press Enter to continue"

# tput clear

cyan "#-------------------------------------------------------------------------------
# REVOKE AWS CREDENTIALS
#-------------------------------------------------------------------------------\n"

cyan 'What if these credentials were leaked?'
green "#==> Revoke the credentials - via CLI."
export AWS_LEASE_ID=$(grep "lease_id" /tmp/phan-s3-ec2-all-role.txt | awk '{print $NF}' | tail -n 1)
pe "echo $AWS_LEASE_ID"
pe "vault lease revoke $AWS_LEASE_ID"

yellow "The AWS IAM user account is no longer there"
echo
cyan 'What if all my credentials for a role were leaked?'
green '#==> Revoke the credentials with a prefix of the role.'
pe "vault lease revoke -prefix aws/creds/phan-s3-ec2-all-role"
p "Press Enter to continue"

tput clear
cyan "#------------------------------------------------------------------------------
# CREATE A NEW SET OF AWS CREDENTIALS - VIA API
#------------------------------------------------------------------------------\n"
echo

green "#==> Create lease - via API"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" \
  -X PUT $VAULT_ADDR/v1/aws/creds/phan-s3-ec2-all-role | jq "." | \
  tee /tmp/phan-s3-ec2-all-role.txt'
pe 'export LEASE_ID=$(jq -r ".lease_id" < /tmp/phan-s3-ec2-all-role.txt)'

green "#==> List leases - via API"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" \
  -X LIST $VAULT_ADDR/v1/sys/leases/lookup/aws/creds/phan-s3-ec2-all-role | jq "." '

echo
green "#--> Renew leases"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" \
  -X PUT $VAULT_ADDR/v1/sys/leases/renew/$LEASE_ID | jq "."'

echo
green "#--> Revoke leases"
pe 'curl -s -H "X-Vault-Token:$VAULT_TOKEN" \
  -X PUT $VAULT_ADDR/v1/sys/leases/revoke/$LEASE_ID | jq "."'

echo
red "Be sure to revoke all leases before trying to complete the exercise."

echo
cyan "
Hopefully you saw how easy it is create and revoke dynamic secrets with Vault.
Vault ensures that they only exist for the duration that they are needed.
"

white "
This concludes the AWS dynamic secrets engine component of the demo."

p "Press any key to return to menu..."

