#!/bin/bash
cp /transit-app-example/backend/config.ini /transit-app-example/backend/config.ini.bak

cat << EOF > ~/transit-app-example/backend/config.ini
[DEFAULT]
LogLevel = WARN
[DATABASE]
Address=mysql-1
Port=3306
User=root
Password=root
Database=my_app
[VAULT]
Enabled = False
DynamicDBCreds = False
ProtectRecords=False
Address=http://localhost:8200
#Address=vault.service.consul
Token=root
KeyPath=lob_a/workshop/transit
KeyName=customer-key
EOF

# cat << EOF > ~/transit-app-example/backend/config.ini
# [DEFAULT]
# LogLevel = WARN
# [DATABASE]
# Address=${MYSQL_HOST}.mysql.database.azure.com
# Port=3306
# User=hashicorp@${MYSQL_HOST}
# Password=Password123!
# Database=my_app

# [VAULT]
# Enabled = False
# DynamicDBCreds = False
# ProtectRecords=False
# Address=http://localhost:8200
# #Address=vault.service.consul
# Token=root
# KeyPath=lob_a/workshop/transit
# KeyName=customer-key
# EOF