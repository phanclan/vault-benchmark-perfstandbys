name: vault-configuration
class: title, shelf, no-footer, fullbleed
background-image: url(https://hashicorp.github.io/field-workshops-assets/assets/bkgs/HashiCorp-Title-bkg.jpeg)

# Vault Configuration

![:scale 15%](images/HashiCorp_Icon_White.png)

---
name: vault-configuration-common
class: compact,col-2

# Vault Common Configuration Parameters

.smaller[
- `listener` stanza
  - `api_addr` - address Vault listens on. Common is `0.0.0.0:8200`
  - `cluster_address`
  - `tls_disable = "true"` for testing
- `storage "consul" {}` Specify consul as storage
  - `address` specify local consul agent.
- `api_addr` - Tells clients where to go. Set to IP/FQDN that clients can reach. `https://<public_ip>:8200`
  - Shows up as **Active Node Address** in Vault Status
- `cluster_addr` - Uses same address as api_addr but port number one higher. `https://<public_ip>:8201`
  - This is always **https** even if you specify **http**.
]

```go
api_addr = https://<public_ip>:8200
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
listener "tcp" {
  address       = "0.0.0.0:8200"
  cluster_addr  = "${IP_ADDRESS}:8201"
  tls_disable   = "true"
}
```

???

```
https://github.com/sharabinth/vault-ha-dr-replica/blob/master/scripts/setupVaultServer.sh
NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | sort -r | head -n 1)
IP_ADDRESS=$(ip address show $NETWORK_INTERFACE | awk '{print $2}' | egrep -o '([0-9]+\.){3}[0-9]+')
HOSTNAME=$(hostname -s)
```

---

https://groups.google.com/forum/?utm_medium=email&utm_source=footer#!msg/vault-tool/jsrM9Fj0ttc/KAPjlpxxAwAJ

---