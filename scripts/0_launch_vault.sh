. env.sh
# Root token and 
tput clear
green "Vault start up data sent to /tmp/vault.log"
vault server -dev > /tmp/vault.log 2>&1 &
sleep 1
#
green "Send Vault audit logs to /vault/logs/audit.log"
vault audit enable file file_path=vault/logs/audit.log log_raw=true
osascript -e tell application "iTerm"