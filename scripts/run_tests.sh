#!/usr/bin/env bash

# Run read test in background
# Make sure that the secrets already exist in Vault before running this test
# You can use write-secrets.lua (after some modification) to populate them
nohup wrk -t4 -c16 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s read-secrets.lua ${VAULT_ADDR} -- 1000 false > prod-test-read-1000-random-secrets-t4-c16-6hours.log &

# Run list test in background
# Make sure that the secrets already exist in Vault before running this test
# You can use write-secrets.lua (after some modification) to populate them
nohup wrk -t1 -c2 -d60s -H "X-Vault-Token: $VAULT_TOKEN" -s list-secrets.lua ${VAULT_ADDR} -- false > prod-test-list-100-secrets-t1-c2-6hours.log &

# Run authentication/revocation test in background
nohup wrk -t1 -c16 -d60s -H "X-Vault-Token: $VAULT_TOKEN" -s authenticate-and-revoke.lua ${VAULT_ADDR} > prod-test-authenticate-revoke-t1-c16-6hours.log &

# Run write/delete test in background
nohup wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-delete-secrets.lua ${VAULT_ADDR} -- 1 100 > prod-test-write-and-delete-100-secrets-t1-c1-6hours-test1.log &

# Run write/delete test in background
nohup wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-delete-secrets.lua ${VAULT_ADDR} -- 2 100 > prod-test-write-and-delete-100-secrets-t1-c1-6hours-test2.log &

# Run write/delete test in background
nohup wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-delete-secrets.lua ${VAULT_ADDR} -- 3 100 > prod-test-write-and-delete-100-secrets-t1-c1-6hours-test3.log &

# Run write/delete test in background
nohup wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-delete-secrets.lua ${VAULT_ADDR} -- 4 100 > prod-test-write-and-delete-100-secrets-t1-c1-6hours-test4.log &

# Run write/delete test in background
nohup wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-delete-secrets.lua ${VAULT_ADDR} -- 5 100 > prod-test-write-and-delete-100-secrets-t1-c1-6hours-test5.log &

# Run write/delete test in background
nohup wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-delete-secrets.lua ${VAULT_ADDR} -- 6 100 > prod-test-write-and-delete-100-secrets-t1-c1-6hours-test6.log &

# Run write/delete test in background
nohup wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-delete-secrets.lua ${VAULT_ADDR} -- 7 100 > prod-test-write-and-delete-100-secrets-t1-c1-6hours-test7.log &

# Run write/delete test in background
nohup wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-delete-secrets.lua ${VAULT_ADDR} -- 8 100 > prod-test-write-and-delete-100-secrets-t1-c1-6hours-test8.log &

# Run write/delete test in background
nohup wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-delete-secrets.lua ${VAULT_ADDR} -- 9 100 > prod-test-write-and-delete-100-secrets-t1-c1-6hours-test9.log &

# Run write/delete test in background
nohup wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-delete-secrets.lua ${VAULT_ADDR} -- 10 100 > prod-test-write-and-delete-100-secrets-t1-c1-6hours-test10.log &
