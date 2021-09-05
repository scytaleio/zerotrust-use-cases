#/bin/bash

set -e

bb=$(tput bold)
nn=$(tput sgr0)

register() {
    kubectl exec -n spire spire-server-0 -c spire-server -- /opt/spire/bin/spire-server entry create $@
}

echo "${bb}Creating registration entry for the backend - envoy...${nn}"
register \
    -parentID spiffe://${TRUST_DOMAIN}/ns/spire/sa/spire-agent \
    -spiffeID spiffe://${TRUST_DOMAIN}/ns/spire/sa/default/mongo-backend \
    -selector k8s:ns:spire \
    -selector k8s:sa:default \
    -selector k8s:pod-label:app:mongo \
    -selector k8s:container-name:envoy

echo "${bb}Creating registration entry for the frontend - envoy...${nn}"
register \
    -parentID spiffe://${TRUST_DOMAIN}/ns/spire/sa/spire-agent \
    -spiffeID spiffe://${TRUST_DOMAIN}/ns/spire/sa/default/mongo-client \
    -selector k8s:ns:spire \
    -selector k8s:sa:default \
    -selector k8s:pod-label:app:client \
    -selector k8s:container-name:envoy

echo "${bb}Listing created registration entries...${nn}"
kubectl exec -n spire spire-server-0 -- /opt/spire/bin/spire-server entry show
