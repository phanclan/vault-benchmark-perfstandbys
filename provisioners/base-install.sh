#!/bin/bash
set -x
apt-get update
apt-get install -y apache2 jq unzip resolvconf make tree nginx

# Cloud Tools
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "<h1>You are on `hostname`</h1>" | sudo tee /var/www/html/index.html


