#!/usr/bin/env bash
set -x
echo "==> Base"

function ssh-apt {
  sudo DEBIAN_FRONTEND=noninteractive apt-get -yqq \
    --allow-downgrades \
    --allow-remove-essential \
    --allow-change-held-packages \
    -o Dpkg::Use-Pty=0 \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "$@"
}
# INFO: https://stackoverflow.com/questions/33370297/apt-get-update-non-interactive

echo "--> Adding helper for IP retrieval"
sudo tee /etc/profile.d/ips.sh > /dev/null <<EOF
function private_ip {
  curl -s http://169.254.169.254/latest/meta-data/local-ipv4
}

function public_ip {
  curl -s http://169.254.169.254/latest/meta-data/public-ipv4
}
EOF
source /etc/profile.d/ips.sh

echo "#--> Writing profile for aliases"

sudo tee /etc/profile.d/aliases.sh > /dev/null <<"EOF"
#!/bin/bash

alias la='ls -A'
alias ll='ls -alF'
alias ls='ls --color=auto'

#--> Terraform
alias tf='terraform'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfi='terraform init'
alias tfp='terraform plan'

#--> docker-compose
alias dc="docker-compose"

#--> Git
alias ga="git add"
alias gc="git commit"
alias gcm="git commit -m"
alias gco="git checkout"
alias gds="git diff --staged"
alias gdu="git diff --unstaged"
alias gfa="git fetch --all"
alias gm="git merge"
alias gpsh="git push"
alias gpll="git pull"
alias gs="git status"
alias gu="git pull" 
EOF
source /etc/profile.d/aliases.sh

echo "--> Updating apt-cache"
ssh-apt update

echo "#--> Installing dnsmasq"
sudo apt-get install -y -q dnsmasq

echo "#--> Configuring DNSmasq"
sudo bash -c "cat > /etc/dnsmasq.d/10-consul" << EOF
server=/consul/127.0.0.1#8600
EOF

sudo cp -a /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
sudo tee /etc/dnsmasq.conf <<EOF
listen-address=127.0.0.1
port=53
bind-interfaces
#domain-needed
#bogus-priv
resolv-file=/etc/resolv.dnsmasq
EOF

# sudo tee /etc/resolv.dnsmasq <<"EOF"
# nameserver 169.254.169.253 
# EOF

# sudo bash -c "echo 'supersede domain-name-servers 127.0.0.1, 169.254.169.253;' >> /etc/dhcp/dhclient.conf"

sudo systemctl restart dnsmasq

configure_systemd_resolved() {
sudo tee -a /etc/systemd/resolved.conf > /dev/null <<EOF
DNS=127.0.0.1
Domains=~consul
EOF

sudo systemctl restart systemd-resolved
}


if [[ $(lsb_release -rs) == 18.04 ]]; then
  configure_systemd_resolved
fi

sleep 5

echo "==> Base is done!"
