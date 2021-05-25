#!/bin/bash 

apt-get update -yq
apt-get install unzip jq -yq 
VAULT_VERSION="1.3.1"
curl -sO https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip

unzip vault_${VAULT_VERSION}_linux_amd64.zip
mv vault /usr/local/bin/
mkdir /etc/vault
mkdir -p /var/lib/vault/data
useradd --system --home /etc/vault --shell /bin/false vault
chown -R vault:vault /etc/vault /var/lib/vault/

cat <<EOF | sudo tee /etc/systemd/system/vault.service
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault/config.hcl

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault/config.hcl
ExecReload=/bin/kill --signal HUP 
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitBurst=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


touch /etc/vault/config.hcl


cat <<EOF | sudo tee /etc/vault/config.hcl
disable_cache = true
disable_mlock = true
ui = true
listener "tcp" {
   address          = "0.0.0.0:8200"
   tls_disable      = 1
}
storage "file" {
   path  = "/var/lib/vault/data"
 }
api_addr         = "http://0.0.0.0:8200"
max_lease_ttl         = "10h"
default_lease_ttl    = "10h"
cluster_name         = "vault"
raw_storage_endpoint     = true
disable_sealwrap     = true
disable_printable_check = true
EOF


systemctl daemon-reload
systemctl enable --now vault
export VAULT_ADDR=http://127.0.0.1:8200 >> ~/.bashrc

source ~/.bashrc 

sleep 10s

echo "Initialize Vault"
vault operator init | tee /tmp/vault.init > /dev/null

keys=$(cat /tmp/vault.init | grep '^Unseal' | awk '{print $4}')
COUNTER=1
for key in $keys; do
  export unseal_key_$COUNTER="$key"
  COUNTER=$((COUNTER + 1))
done

export VAULT_TOKEN=$(cat /tmp/vault.init | grep '^Initial' | awk '{print $4}')

echo "unsealing vault operator"
vault operator unseal $unseal_key_1
vault operator unseal $unseal_key_2
vault operator unseal $unseal_key_3


