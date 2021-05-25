#!/bin/bash 


display_usage() { 
	echo "This script must be run trust domain as input" 
	echo -e "\nUsage: $0 <trust-domain> \n" 
} 

if [  $# -le 1 ]; then 
		display_usage
		exit 1
fi 



TRUST_DOMAIN=$1
export VAULT_TOKEN=$(cat /tmp/vault.init | grep '^Initial' | awk '{print $4}')
export VAULT_ADDR=http://127.0.0.1:8200

echo "enabling vault secret store"

vault secrets enable -path=secret kv

echo "store secrets"

vault kv put secret/my-super-secret test=123

echo "enabling JWT on vault"

vault auth enable jwt


echo "enabling spire OIDC provider in jwt config"

vault write auth/jwt/config oidc_discovery_url=https://${TRUST_DOMAIN} default_role=“dev”

cat > /tmp/policy.hcl <<END
path "secret/my-super-secret" {
   capabilities = ["read"]
}
END

echo "writing dev policy to vault"

vault policy write my-dev-policy /tmp/policy.hcl 

echo "register workload with spire"

spire-server entry create -parentID spiffe://${TRUST_DOMAIN}/myagent  -spiffeID spiffe://${TRUST_DOMAIN}/vault -selector unix:gid:0 -registrationUDSPath /var/run/spire/sockets/server.sock

vault write auth/jwt/role/dev role_type=jwt user_claim=sub bound_audiences=TESTING bound_subject=spiffe://${TRUST_DOMAIN}/vault token_ttl=24h token_policies=my-dev-policy

echo "generating token for vault"
sleep 10

token=$(spire-agent api fetch jwt  -audience TESTING  -socketPath /run/spire/sockets/agent.sock |sed '2!d' | sed 's/[[:space:]]//g')

cat > /tmp/token <<END
{"role": "dev","jwt": "$token"}
END

echo "extracting auth token to connect to vault"

auth_token=$(curl --request POST --data @/tmp/token ${VAULT_ADDR}/v1/auth/jwt/login | jq -r '.auth.client_token')

echo $auth_token

echo "Testing vault connectivity with auth token"

return_code=$(curl -sL -w "%{http_code}\\n"  -H "X-Vault-Token: $auth_token" ${VAULT_ADDR}/v1/secret/my-super-secret  -o /dev/null)
   
if [[ $return_code == "200" ]]; 
then
   echo "vault connectivity successful";
else
   echo "access forbidden please validate the auth_token";
fi
