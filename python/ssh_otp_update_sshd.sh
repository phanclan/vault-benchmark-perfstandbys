#!/bin/bash
sed -i -e '/^ChallengeResponseAuthentication/ s/no/yes/' /etc/ssh/sshd_config
sed -i -e 's/#UsePAM/UsePAM/' -e '/UsePAM/ s/no/yes/' /etc/ssh/sshd_config
# sed -i -e '/#PasswordAuthentication/ a PasswordAuthentication no' /etc/ssh/sshd_config
sed -i -e 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
# Start/Restart the SSH service - example for Docker
pkill sshd
/usr/sbin/sshd -D &
