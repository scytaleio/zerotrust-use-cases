#!/bin/bash -xeu 
set -o pipefail
set -o xtrace

if [[ "$#" -ne 3 ]]; then
        echo "Usage: ./install-envoy <client-spiffe-id> <listen-port> <upstream-port>"
        exit
fi

if [[ ! -f "/etc/redhat-release" ]]; then
        echo "This script is intended only for Red Hat or CentOS distributions"
        exit
fi

if [[ $(id -u) -ne 0 ]]; then
        echo "Must run as root"
        exit
fi

if [[ -d /opt/envoy ]]; then
	echo "Envoy appears to already be installed"
	exit
fi

CLIENT_SPIFFE_ID=$1
LISTEN_PORT=$2
UPSTREAM_PORT=$3

yum install -y nc
if [[ $(nc -z localhost "${SERVER_PORT}") ]]; then
	echo "The upstream service on port ${UPSTREAM_PORT} does not seem to be listening."
	exit
fi

if [[ ! -S "/var/run/spire/sockets/agent.sock" ]]; then
	echo "The socket at /var/run/spire/sockets/agent.sock does not exist"
	exit
fi

if [[ ! -w "/var/run/spire/sockets/agent.sock" ]]; then
        echo "The socket at /var/run/spire/sockets/agent.sock needs to be writeable"
	exit
fi


mkdir -p /opt/envoy
pushd /opt/envoy
curl -L https://getenvoy.io/cli | bash -s -- -b /opt/envoy

# Make sure Envoy can run at all
./getenvoy run standard:1.17.1 -- --version

ESCAPED_SPIFFE_ID=$(printf '%s\n' "${CLIENT_SPIFFE_ID}" | sed -e 's/[\/&]/\\&/g')

cp /home/vagrant/envoy_config.yaml.tmpl /opt/envoy/envoy.yaml
sed -i s/TEMPLATE_LISTEN_PORT/${LISTEN_PORT}/g envoy.yaml
sed -i s/TEMPLATE_UPSTREAM_PORT/${UPSTREAM_PORT}/g envoy.yaml
sed -i s/TEMPLATE_CLIENT_SPIFFE_ID/${ESCAPED_SPIFFE_ID}/g envoy.yaml

nohup /opt/envoy/getenvoy run standard:1.17.1 -- --config-path /opt/envoy/envoy.yaml --log-level trace > /var/log/envoy_debug.log 2>&1 </dev/null & 

