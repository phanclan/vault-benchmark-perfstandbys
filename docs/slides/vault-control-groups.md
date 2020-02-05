name: vault-control-groups
class: title, shelf, no-footer, fullbleed
background-image: url(https://hashicorp.github.io/field-workshops-assets/assets/bkgs/HashiCorp-Title-bkg.jpeg)

# Vault Control Groups

## Peter Phan, pphan@hashicorp.com

![:scale 15%](images/HashiCorp_Icon_White.png)

---
name: vault-cg-intro
class: compact,col-2

# Scenario

.smaller[
- Scenario: User Bob Smith has `read-only` permission on the "EU_GDPR_data/data/orders/*" path
- However, someone in the `acct_manager` group must approve, before he can read the data.
- Ellen Wright, a member of the `acct_manager` group, can authorize Bob's request.

![](https://d33wubrfki0l68.cloudfront.net/107e13b9f0f98da8d8bf96548b3f72af66507b9f/cba29/static/img/vault-ctrl-grp-1.png)

You are going to perform the following:

1. Implement a control group
1. Deploy the policies
1. Setup entities and a group
1. Verification
1. ACL Policies vs. Sentinel Policies
]

---
name: step-1-implement-a-control-group
class: compact,col-2

# Step 1: Implement a control group

.smaller[
Create a policy named `read-gdpr-order.hcl`. Bob needs `read` permissions on `EU_GDPR_data/data/orders/*`:
]

```go
path "EU_GDPR_data/data/orders/*" {
  capabilities = [ "read" ]
}
```

.smaller[
Now, add `control group` to this policy:

- The number of approvals is set to `1` (simple and easy to test).
- Any member of the identity group, `acct_manager` can approve the read request.
- Although this example has only one factor (authorizer), you can add as many factor blocks as you need.
]

```go
path "EU_GDPR_data/data/orders/*" {
  capabilities = [ "read" ]

  control_group = {
    factor "authorizer" {
        identity {
            group_names = [ "acct_manager" ]
            approvals = 1
        }
    }
  }
}
```

---
class: compact

Create a policy for the `acct_manager` group named `acct_manager.hcl`.

```go
# To approve the request
path "sys/control-group/authorize" {
    capabilities = ["create", "update"]
}

# To check control group request status
path "sys/control-group/request" {
    capabilities = ["create", "update"]
}
```

NOTE: The authorizer (`acct_manager`) must have `create` and `update` permission on the `sys/control-group/authorize` endpoint so that they can approve the request.

---
name: step-2-deploy-the-policies
class: compact,col-2

# Step 2: Deploy the policies

.smaller[
Deploy the `read-gdpr-order` and `acct_manager` policies that you wrote.

CLI command / API call using cURL / Web UI
]

## CLI command

```shell
# Create read-gdpr-order policy
$ vault policy write read-gdpr-order read-gdpr-order.hcl

# Create acct_manager policy
$ vault policy write acct_manager acct_manager.hcl
```

## API call using cURL

```shell
# Construct API request payload to create read-gdpr-read policy
$ tee payload-1.json <<EOF
{
  "policy": "path \"EU_GDPR_data/data/orders/*\" {\n  capabilities = [ \"read\" ]\n\n  control_group = {\n    factor \"authorizer\" {\n        identity {\n            group_names = [ \"acct_manager\" ]\n            approvals = 1\n        }\n    }\n  }\n}"
}
EOF

# Create read-gdpr-order policy
$ curl --header "X-Vault-Token: ..." \
       --request PUT \
       --data @payload-1.json \
       http://127.0.0.1:8200/v1/sys/policies/acl/read-gdpr-order

# Construct API request payload to create acct_manager policy
$ tee payload-2.json <<EOF
{
 "policy": "# To approve the request\npath \"sys/control-group/authorize\" {\n    capabilities = [\"create\", \"update\"]\n}\n\n# To check control group request status\npath \"sys/control-group/request\" {\n    capabilities = [\"create\", \"update\"]\n}"
}
EOF

# Create acct_manager policy
$ curl --header "X-Vault-Token: ..." \
      --request PUT \
      --data @payload-2.json \
      http://127.0.0.1:8200/v1/sys/policies/acl/acct_manager
```

---
class: compact,col-2

# Web UI

.smaller[
- Open a web browser and launch the Vault UI (e.g. http://127.0.0.1:8200/ui) and then login.
- Click the **Policies** tab, and then select **Create ACL policy**.
- Toggle **Upload file**, and click **Choose a file** to select your `read-gdpr-order.hcl` file you authored at Step 1. This loads the policy and sets the **Name** to be `read-gdpr-order`.
![Create Policy](https://d33wubrfki0l68.cloudfront.net/d0133fc2c5516c66b9c13bbf733d11e56e37ed66/338dc/static/img/vault-ctrl-grp-2.png)
- Click **Create Policy** to complete.
- Repeat the steps to create a policy for `acct_manager`.
]

---
name: step-3-setup-entities-and-a-group
class: compact,col-2

# Step 3: Setup entities and a group

This step only demonstrates CLI commands and Web UI to create entities and groups. Refer to the [Identity - Entities and Groups](https://learn.hashicorp.com/vault/identity-access-management/iam-identity) guide if you need the full details.

- Create a user (`bob`) and an `acct_manager` group with `ellen` as a group member.

NOTE: For the purpose of this guide, use the `userpass` auth method to create user `bob` and `ellen` so that the scenario can be easily tested.

CLI command / Web UI

---
class: compact,col-2

# CLI command

```shell
# Enable userpass
set +e
vault auth enable userpass
set -e

# Create a user, bob
vault write auth/userpass/users/bob password="training"

# Create a user, ellen
vault write auth/userpass/users/ellen password="training"
```

```shell
# Retrieve the userpass mount accessor and save it in a file named accessor.txt
vault auth list -format=json | jq -r '.["userpass/"].accessor' > /tmp/accessor.txt

# Create Bob Smith entity and save the identity ID in the entity_id_bob.txt
vault write -format=json identity/entity name="Bob Smith" policies="read-gdpr-order" \
  metadata=team="Processor" \
  | jq -r ".data.id" > /tmp/entity_id_bob.txt

# Add an entity alias for the Bob Smith entity
vault write identity/entity-alias name="bob" \
  canonical_id=$(cat /tmp/entity_id_bob.txt) \
  mount_accessor=$(cat /tmp/accessor.txt)

# Create Ellen Wright entity and save the identity ID in the entity_id_ellen.txt
vault write -format=json identity/entity name="Ellen Wright" policies="default" \
  metadata=team="Acct Controller" \
  | jq -r ".data.id" > /tmp/entity_id_ellen.txt

# Add an entity alias for the Ellen Wright entity
vault write identity/entity-alias name="ellen" \
  canonical_id=$(cat /tmp/entity_id_ellen.txt) \
  mount_accessor=$(cat /tmp/accessor.txt)

# Finally, create acct_manager group and add Ellen Wright entity as a member
vault write identity/group name="acct_manager" \
  policies="acct_manager" \
  member_entity_ids=$(cat /tmp/entity_id_ellen.txt)
```

???

»Web UI

    Click the Access tab, and select Enable new method.

    Select Username & Password and click Next.

    Click Enable Method.

    Click the Vault CLI shell icon (>_) to open a command shell. Execute vault write auth/userpass/users/bob password=training to create a new user bob. Create Policy

    Enter vault write auth/userpass/users/ellen password=training to create a new user ellen.

    Click the icon (>_) again to hide the shell.

    From the Access tab, select Entities and then Create entity.

    Populate the Name, Policies and Metadata fields as shown below. Create Entity

    Click Create.

    Select Create alias. Enter bob in the Name field and select userpass/ (userpass) from the Auth Backend drop-down list.

    Click Create.

    Return to the Entities tab and then Create entity.

    Populate the Name, Policies and Metadata fields as shown below. Create Entity

    Click Create.

    Select Create alias. Enter ellen in the Name field and select userpass/ (userpass) from the Auth Backend drop-down list.

    Click Create.

    Click Groups from the left navigation, and select Create group.

    Enter acct_manager in the Name, and again enter acct_manager in the Policies fields.

    In the Member Entity IDs field, select Ellen Wright and then click Create.


