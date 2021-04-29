#!/bin/bash -xeu
set -o xtrace
set -o pipefail

ISTIO="istio-1.9.0"
FRONTEND_ID="spiffe://test.com/ns/default/sa/spire-istio-envoy"
BACKEND_ID="spiffe://test.com/backend"
TRUST_DOMAIN="spiffe://test.com"

# Check binaries: kind, kubectl, docker, helm
which kind || (echo "kind not found"; exit 1)
which kubectl || (echo "kubectl not found"; exit 1)
which helm || (echo "helm not found"; exit 1)
(helm version | grep "Version:\"v3.") || (echo "Helm is not version 3"; exit 1)
which docker || (echo "docker not found"; exit 1)

# First create the BLUE cluster
kind delete cluster --name=blue  # make sure we're starting from a blank slate
sleep 30
kind create cluster --name=blue --config=blue-kind-config.yaml
kind export kubeconfig --name=blue
sleep 60

# Install MetalLB on the BLUE cluster
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/namespace.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/master/manifests/metallb.yaml
sleep 30
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
sleep 10
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

# Wait for the LB to get created
sleep 30
# Get a join token for the SPIRE server
SPIRE_SERVER_IP=$(kubectl get svc/spire-server-lb-service -n spire -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

cat > environment <<END
SPIRE_SERVER_IP=${SPIRE_SERVER_IP}
END
