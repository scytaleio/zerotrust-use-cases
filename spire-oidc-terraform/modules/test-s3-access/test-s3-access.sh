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
OIDC_ROLE_ARN=$2
S3_BUCKET_NAME=$3

register() {
    kubectl exec -n spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry create $@
}

echo "${bb}Creating registration entry for the client workload ...${nn}"

register \
    -parentID spiffe://${TRUST_DOMAIN}/ns/spire/sa/spire-agent \
    -spiffeID spiffe://${TRUST_DOMAIN}/ns/spire-oidc/sa/default \
    -selector k8s:ns:spire-oidc \
    -selector k8s:sa:default 

spire_agent_pod=`kubectl get pods -n spire|grep spire-agent|awk '{print $1}'|head -1`
token_temp=$(kubectl exec -n spire ${spire_agent_pod} -- sh -c "/opt/spire/bin/spire-agent api fetch jwt -audience mys3  -socketPath /opt/spire/sockets/agent.sock")

kubectl exec -n spire-oidc deploy/oidc-client -- sh -c "apk add --no-cache -q python3 py3-pip && pip3 install --upgrade -q pip && pip3 install -q awscli"
kubectl exec -n spire-oidc deploy/oidc-client -- sh -c "echo \"${token_temp}\" |sed '2!d' | sed 's/[[:space:]]//g' > /tmp/token"
kubectl exec -n spire-oidc deploy/oidc-client -- sh -c "aws sts get-caller-identity;AWS_ROLE_ARN=${OIDC_ROLE_ARN} AWS_WEB_IDENTITY_TOKEN_FILE=/tmp/token aws s3 cp s3://${S3_BUCKET_NAME}/scytale_object /tmp/test.txt"
 
s3filecontents="$(kubectl exec -n spire-oidc deploy/oidc-client -- cat /tmp/test.txt)"

if [[ "${s3filecontents}" == "oidc-tutorial file" ]]; 
then
   echo "Successfully accessed test.txt file from s3 bucket";
else
   echo "Failed to access test.txt file from s3 bucket";
fi

