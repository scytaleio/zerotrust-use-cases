#!/bin/bash -xeuo pipefail

ISTIO="istio-1.9.0"
FRONTEND_ID="spiffe://test.com/ns/default/sa/spire-istio-envoy"
BACKEND_ID="spiffe://test.com/backend"
TRUST_DOMAIN="spiffe://test.com"

# Check binaries: kind, kubectl, docker, helm
which kind || (echo "kind not found"; exit 1)
which kubectl || (echo "kubectl not found"; exit 1)
which helm || (echo "helm not found"; exit 1)
which docker || (echo "docker not found"; exit 1)
(helm version | grep "Version:\"v3.") || (echo "Helm is not version 3"; exit 1)
jq


# First create the BLUE cluster
kind delete cluster --name=blue  # make sure we're starting from a blank slate
kind create cluster --name=blue --config=blue-kind-config.yaml
kind export kubeconfig --name=blue

# Install MetalLB on the BLUE cluster
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/namespace.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/metallb.yaml
sleep 5
subnet=`cmds/get_docker_subnet.sh`
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - ${subnet}0.100-${subnet}0.150
EOF

# Download the current version of Istio. 
rm -rf $ISTIO
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.9.0 sh -

# Install Istio
$ISTIO/bin/istioctl x precheck
$ISTIO/bin/istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled

# Install useful utilities for demo purposes
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/addons/kiali.yaml
sleep 5
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/addons/kiali.yaml
kubectl apply -f $ISTIO/samples/addons/kiali.yaml
kubectl apply -f $ISTIO/samples/addons/jaeger.yaml
kubectl apply -f $ISTIO/samples/addons/grafana.yaml
kubectl apply -f $ISTIO/samples/addons/prometheus.yaml
# Ambassador ingress is nice for exposing any HTTP services
kubectl apply -f https://github.com/datawire/ambassador-operator/releases/latest/download/ambassador-operator-crds.yaml
kubectl apply -n ambassador -f https://github.com/datawire/ambassador-operator/releases/latest/download/ambassador-operator-kind.yaml
kubectl wait --timeout=180s -n ambassador --for=condition=deployed ambassadorinstallations/ambassador
# Sleep pod for use as a curl client
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/sleep/sleep.yaml

# Install the SPIRE server, agents, and k8s-workload-registrar with all defaults
helm install spire charts/spire-chart
# LB so it can be accessed outside the cluster
kubectl apply -f util/spire-server-lb.yaml
# This helps with debugging in case the LB isn't working
kubectl apply -f util/spire-nodeport.yaml

# Setup up the GREEN cluster
kind delete cluster --name=green  # make sure we're starting from a blank slate
kind create cluster --name=green --config=green-kind-config.yaml
kind export kubeconfig --name=green

# Install MetalLB on the GREEN cluster
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/namespace.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/metallb.yaml
sleep 5
subnet=`cmds/get_docker_subnet.sh`
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - ${subnet}0.200-${subnet}0.250
EOF

# Get a join token for the SPIRE server
cmds/set_context_blue.sh
join_token=`cmds/generate_join_token.sh`
blue_ip=$(kubectl get svc/spire-server-lb-service -n spire -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

# 13 Install the SPIRE agent on the GREEN cluster, point it it at the IP address and join token from step 10
cmds/set_context_green.sh
helm install spire-agent charts/spire-agent-chart \
	--set spireServerAddress=$blue_ip \
	--set spireServerPort=8081 \
	--set joinToken=$join_token

# 15 Run quote service on GREEN cluster
cmds/set_context_green.sh
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.9/samples/sleep/sleep.yaml
kubectl apply -f util/quote-service.yaml

# Install the gateway for the backend. We have to do this first so we have the IP address
# to point the frontend to.
cmds/set_context_green.sh
helm install --set mode=backend \
             --set upstreamHost=quote \
	     --set upstreamPort=80 \
	     --set backendSpiffeId="$BACKEND_ID" \
	     --set frontendSpiffeId="$FRONTEND_ID" \ 
	     --set trustDomain="$TRUST_DOMAIN" \ 
	     spire-istio-envoy-backend charts/spire-istio-envoy/

kubectl apply -f util/backend-lb.yaml

green_ip=$(kubectl get svc/backend-lb-service -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Install the gateway for the frontend.
cmds/set_context_blue.sh
helm install --set mode=frontend \
             --set upstreamHost=$green_ip \
	     --set upstreamPort=443 \
	     --set backendSpiffeId="$BACKEND_ID" \
	     --set frontendSpiffeId="$FRONTEND_ID" \
	     --set trustDomain="$TRUST_DOMAIN" \ 
	     spire-istio-envoy-frontend charts/spire-istio-envoy/

cmds/set_context_blue.sh
cmds/add_backend_registration_entry.sh

# 18 Demonstrate that curl on the BLUE cluster can communicate with the echo server on the GREEN cluster.
cmds/set_context_blue.sh
cmds/run_test_command.sh

