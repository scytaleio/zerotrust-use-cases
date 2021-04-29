#!/bin/bash -xeu 
set -o pipefail
set -o xtrace

RELEASE="spire-0.12.1"
SPIRE_URL="https://github.com/spiffe/spire/releases/download/v0.12.1/spire-0.12.1-linux-x86_64-glibc.tar.gz"

if [[ "$#" -ne 4 ]]; then
	echo "Usage: ./install-spire <trust-domain> <spire-server-address> <spire-server-port> <join_token>"
	exit 1
fi

if [[ ! -f "/etc/redhat-release" ]]; then
	echo "This script is intended only for Red Hat or CentOS distributions"
	exit 1
fi

if [[ $(id -u) -ne 0 ]]; then
	echo "Must run as root"
	exit 1
fi

if [[ -d "/opt/spire" ]]; then
	echo "SPIRE agent appears to already be installed in /opt/spire."
	exit 1
fi

if [[ ! -f "/tmp/spire_bootstrap" ]]; then
	echo "The bootstrap trust bundle needs to be placed in /tmp/spire_bootstrap"
	exit 1
fi

TRUST_DOMAIN=$1
SERVER_ADDRESS=$2
SERVER_PORT=$3
JOIN_TOKEN=$4

yum install -y nc
if [[ $(nc -z "${SERVER_ADDRESS}" "${SERVER_PORT}") ]]; then
	echo "The SPIRE server at ${SERVER_ADDRESS}:${SERVER_PORT} does not seem to be listening."
	exit 1
fi

if [[ ! -d "/opt/spire" ]]; then
	mkdir -p /opt/spire
	mkdir -p /tmp/spire
	pushd /tmp/spire
	curl -L "${SPIRE_URL}" > spire.tar.gz
	tar xvzf spire.tar.gz
	mv "${RELEASE}"/* /opt/spire/
	popd
	rm -rf /tmp/spire
fi

mkdir -p /var/run/spire/sockets

cat > /opt/spire/conf/agent/agent.conf <<END
agent {
    data_dir = "/opt/spire/data/agent"
    trust_domain = "${TRUST_DOMAIN}"
    server_address = "${SERVER_ADDRESS}"
    server_port = "${SERVER_PORT}"
    socket_path = "/var/run/spire/sockets/agent.sock"

    trust_bundle_path = "/tmp/spire_bootstrap"
    log_level = "DEBUG"
    log_file = "/var/log/spire_agent.log"
}

plugins {
   KeyManager "disk" {
        plugin_data {
            directory = "/opt/spire/data/agent"
        }
    }

    NodeAttestor "join_token" {
        plugin_data {}
    }

    WorkloadAttestor "unix" {
        plugin_data {}
    }
}
END

# Run the spire agent itself
# Redirect the inputs and outputs so that the SSH shell exits once this command is safely running in the background
nohup  /opt/spire/bin/spire-agent run -config /opt/spire/conf/agent/agent.conf -joinToken $JOIN_TOKEN > output.log 2>&1 </dev/null &
sleep 10

/opt/spire/bin/spire-agent healthcheck -socketPath /var/run/spire/sockets/agent.sock
if [[ $? != 0 ]]; then
	echo "spire-agent startup failed"
	exit 1
fi

/opt/spire/bin/spire-agent api fetch -socketPath /var/run/spire/sockets/agent.sock
if [[ $? != 0 ]]; then
	echo "spire-agent cannot fetch an SVID. Is the needed registration entry created on the server?"
	exit 1
fi
