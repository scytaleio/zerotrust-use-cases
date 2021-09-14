#!/bin/bash 

set -e

bb=$(tput bold)
nn=$(tput sgr0)

display_usage() { 
	echo "This script must be run trust domain as input" 
	echo -e "\nUsage: $0 <trust-domain> \n" 
} 

if [  $# -le 0 ]; then 
		display_usage
		exit 1
fi 

TRUST_DOMAIN=$1

register() {
    kubectl exec -n spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry create $@
}

echo "${bb}Creating registration entry for the vault - vault...${nn}"
register \
    -parentID spiffe://${TRUST_DOMAIN}/ns/spire/sa/spire-agent \
    -spiffeID spiffe://${TRUST_DOMAIN}/ns/spire-vault/sa/default \
    -selector k8s:ns:spire-vault \
    -selector k8s:sa:default 

echo "${bb}Listing created registration entries...${nn}"
kubectl exec -n spire spire-server-0 -- /opt/spire/bin/spire-server entry show

export VAULT_K8S_NAMESPACE="spire-vault"
export VAULT_K8S_PODNAME="$(kubectl -n ${VAULT_K8S_NAMESPACE} get pods | grep 'spire-vault' | awk '{print $1}')"

# Unseal happens while vault gets initialized
echo "store secrets"

kubectl -n ${VAULT_K8S_NAMESPACE} exec ${VAULT_K8S_PODNAME} -- sh -c "export VAULT_TOKEN=\$(cat /home/vault/.vault-token) && vault kv put secret/my-super-secret test=123"

echo "enabling JWT on vault"
kubectl -n ${VAULT_K8S_NAMESPACE} exec ${VAULT_K8S_PODNAME} -- sh -c "export VAULT_TOKEN=\$(cat /home/vault/.vault-token) && vault auth enable jwt"

echo "enabling spire OIDC provider in jwt config"
kubectl -n ${VAULT_K8S_NAMESPACE} exec ${VAULT_K8S_PODNAME} -- sh -c "export VAULT_TOKEN=\$(cat /home/vault/.vault-token) && vault write auth/jwt/config oidc_discovery_url=https://${TRUST_DOMAIN} default_role='dev'"

cat > /tmp/policy.hcl <<END
path "secret/my-super-secret" {
   capabilities = ["read"]
}
END

echo "writing dev policy to vault"
kubectl -n ${VAULT_K8S_NAMESPACE} exec ${VAULT_K8S_PODNAME} -- sh -c "export VAULT_TOKEN=\$(cat /home/vault/.vault-token) && echo -e \"path \\\"secret/my-super-secret\\\" {\\n capabilities = [\\\"read\\\"]\\n }\" > /tmp/policy.hcl;vault policy write my-dev-policy /tmp/policy.hcl"

kubectl -n ${VAULT_K8S_NAMESPACE} exec ${VAULT_K8S_PODNAME} -- sh -c "export VAULT_TOKEN=\$(cat /home/vault/.vault-token) && vault write auth/jwt/role/dev role_type=jwt user_claim=sub bound_audiences=TESTING bound_subject=spiffe://${TRUST_DOMAIN}/ns/spire-vault/sa/default token_ttl=24h token_policies=my-dev-policy"

echo "generating token for vault"
sleep 10

token_temp=$(kubectl exec -n spire-vault deploy/client -- sh -c "/opt/spire/bin/spire-agent api fetch jwt  -audience TESTING  -socketPath /opt/spire/sockets/agent.sock")
token=$(echo "${token_temp}" |sed '2!d' | sed 's/[[:space:]]//g')

echo "Install curl, jq packages"
kubectl -n ${VAULT_K8S_NAMESPACE} exec ${VAULT_K8S_PODNAME} -- sh -c "apk add -q curl jq"

echo "extracting auth token to connect to vault"

auth_token=$(kubectl -n ${VAULT_K8S_NAMESPACE} exec ${VAULT_K8S_PODNAME} -- sh -c "export VAULT_TOKEN=\$(cat /home/vault/.vault-token) && echo \"{\\\"role\\\": \\\"dev\\\", \\\"jwt\\\": \\\"$token\\\"}\" > /tmp/token;curl --request POST --data @/tmp/token \${VAULT_ADDR}/v1/auth/jwt/login | jq -r '.auth.client_token'")

echo $auth_token

echo "Testing vault connectivity with auth token"

return_code=$(kubectl -n ${VAULT_K8S_NAMESPACE} exec ${VAULT_K8S_PODNAME} -- curl -sL -w "%{http_code}\\n"  -H "X-Vault-Token: $auth_token" \${VAULT_ADDR}/v1/secret/my-super-secret  -o /dev/null)
   
if [[ $return_code == "200" ]]; 
then
   echo "vault connectivity successful";
else
   echo "access forbidden please validate the auth_token";
fi


