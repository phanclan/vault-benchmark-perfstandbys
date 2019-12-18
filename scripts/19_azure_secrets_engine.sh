#!/bin/bash
. env.sh

cyan "Running: $0: Enabling Azure Secrets"

pe "vault secrets enable azure"

curl -H "X-Vault-Token: $VAULT_TOKEN" -X POST -d @/tmp/.azure-creds $VAULT_ADDR/v1/azure/config
p

