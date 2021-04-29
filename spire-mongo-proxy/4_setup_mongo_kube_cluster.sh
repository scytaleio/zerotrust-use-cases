#!/bin/bash -xeu 
set -o pipefail

GREEN_IP="172.30.1.2"
GREEN_PORT=20001
BACKEND_ID="spiffe://test.com/backend"
FRONTEND_ID="spiffe://test.com/ns/default/sa/spire-envoy-tcp"
TRUST_DOMAIN="spiffe://test.com"
helm uninstall mongodb
helm install mongodb --set persistence.enabled=false bitnami/mongodb --wait

kubectl wait --for=condition=available deployments/mongodb

helm uninstall spire-envoy-tcp
helm install --set mode=frontend \
             --set upstreamHost=$GREEN_IP \
             --set upstreamPort=20001 \
             --set backendSpiffeId="$BACKEND_ID" \
             --set frontendSpiffeId="$FRONTEND_ID" \
             --set trustDomain="$TRUST_DOMAIN" \
             spire-envoy-tcp charts/spire-envoy-tcp \
             --wait
