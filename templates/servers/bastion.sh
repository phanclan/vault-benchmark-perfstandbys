#!/usr/bin/env bash
set -e

echo "--> Start postgres and openldap containers."
git clone https://github.com/phanclan/vault-benchmark-perfstandbys.git
cd vault-benchmark-perfstandbys
docker-compose up -d openldap postgres
