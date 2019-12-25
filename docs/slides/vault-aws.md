class: title, smokescreen, shelf, no-footer
background-image: url(https://story.xaprb.com/slides/adirondack/leo-serrat-533922-unsplash.jpg)

# VAULT AWS DEMO
### Peter Phan, pphan@hashicorp.com

---
layout: true

.footer[
- Copyright © 2019 HashiCorp
- [the components](#components)
- ![logo](https://hashicorp.github.io/field-workshops-assets/assets/logos/HashiCorp_Icon_Black.svg)
]

---
name: getting-started
# Getting Started
This script creates leases in AWS.
- Lease length is 2min.
- Set your variables in `terraform.tfvars`
- Run `tf init` and `tf apply`
- Go to websites
  - http://consul.pphan.hashidemos.io:8500
  - http://vault-0.pphan.hashidemos.io:8200

???

notes


---
name: img-right
class: img-right
![Yosemite](https://story.xaprb.com/slides/adirondack/leo-serrat-533922-unsplash.jpg)

Some text

---
name: vault-aws-run
class: compact,col-2
# Vault AWS Configuration
- Set your variables in `scripts/env.sh`
- Run `17-aws.sh`
- Get vault admin token. 
  - http://consul.pphan.hashidemos.io:8500/ui/dc1/kv/service/vault/admin-token/edit
- Log in to Vault UI with admin token
  - http://vault-0.pphan.hashidemos.io:8200/ui/
- Test ldap login, db, and transit.
  - `./scripts/test_hr_cloud.sh`
- NOTE: If you want to run this script again, need to reload postgres container.
``` shell
ssh ubuntu@bastion.pphan.hashidemos.io
#--> Go to vault repo that you cloned
vault write aws/config/root \
    access_key=$ACCESS_KEY_ID \
    secret_key=$SECRET_ACCESS_KEY
```
- Replace `access_key` and `secret_key` with your keys.\n"

---
name: vault-aws-account
# CONFIGURE AWS ACCOUNT TO USE SECRETS

- Go to IAM Management Console: https://console.aws.amazon.com/iam/home#/users. 
- Create a new User. Click **Add user**.
- Give it **Programmatic Access only**.
- Select `Attach existing policies directly`.
- Click **Create policy**. Select **JSON** tab.
- Paste the policy below. Be sure to overwrite the current contents.
- Name the policy "`hashicorp-vault-lab`"
  - Make sure to replace your `<Account ID>` in the Resource. 
  - When Vault dynamically creates the users, the username starts with the “`vault-`” prefix.
  - The account number can be found in AWS Support Dashboard:'

Sample Policy:
``` json
{
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
}
```

---
name: vault-aws-run
class: compact,col-2

# CREATE VAULT AWS ROLE

Configure a Vault role that maps to a set of permissions in AWS as well as an AWS credential type. 
When users generate credentials, they are generated against this role. An example:

``` shell
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
```