#!/bin/bash  

RELEASE="spire-0.12.1"
SPIRE_URL="https://github.com/spiffe/spire/releases/download/v0.12.1/spire-0.12.1-linux-x86_64-glibc.tar.gz"

TRUST_DOMAIN=$1

touch execution.log

LOG_FILE="./execution.log"

logit() {
    while read
    do
        echo "$(date) $REPLY" >> ${LOG_FILE}
    done
}

exec 3>&1 1>> >(logit) 2>&1


echo "install awscli"

apt-get update -yq

apt-get install awscli -yq 

echo "Installation spire server" 

echo "Extracting server/agent tar bundle" 
 
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

echo "creating symlinks"

ln -s /opt/spire/bin/spire-server /usr/bin/spire-server
ln -s /opt/spire/bin/spire-agent /usr/bin/spire-agent

mkdir -p /var/run/spire/sockets

cat > /opt/spire/conf/server/server.conf <<END
server {
    bind_address = "0.0.0.0"
    bind_port = "8081"
    log_file = "/var/log/spire_server.log"
    trust_domain = "${TRUST_DOMAIN}"
    data_dir = "./data/server"
    log_level = "DEBUG"
    ca_ttl = "168h"
    default_svid_ttl = "48h"
    #AWS requires the use of RSA.  EC cryptography is not supported
    ca_key_type = "rsa-2048"
    jwt_issuer = "https://${TRUST_DOMAIN}"
    ca_subject = {
       country = ["US"],
       organization = ["SPIFFE"],
       common_name = "",
      }
}

plugins {
    DataStore "sql" {
        plugin_data {
            database_type = "sqlite3"
            connection_string = "./data/server/datastore.sqlite3"
        }
    }

    KeyManager "disk" {
        plugin_data {
            keys_path = "./data/server/keys.json"
        }
    }

    NodeAttestor "join_token" {
        plugin_data {}
    }
}
END

echo "Starting spiffe server" 

nohup spire-server run -config /opt/spire/conf/server/server.conf  -registrationUDSPath /var/run/spire/sockets/server.sock &

sleep 15


cat > /opt/spire/conf/agent/agent.conf <<END
agent {
    data_dir = "/opt/spire/data/agent"
    trust_domain = "${TRUST_DOMAIN}"
    server_address = "localhost"
    server_port = 8081
    socket_path = "/var/run/spire/sockets/agent.sock"
    #trust_bundle_path = "/tmp/spire_bootstrap"
    insecure_bootstrap = true
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

echo "Generating token for agent" 

token="$(spire-server token generate -spiffeID spiffe://${TRUST_DOMAIN}/myagent -registrationUDSPath /var/run/spire/sockets/server.sock | cut -d' ' -f2)"

echo "Starting the agent with token $token"

nohup spire-agent run -config /opt/spire/conf/agent/agent.conf -joinToken $token &

sleep 10

spire-agent healthcheck -socketPath /var/run/spire/sockets/agent.sock

if [[ $? != 0 ]]; then
	echo "spire-agent startup failed"
	exit 1
fi

echo "Download and extract OIDC provider bundle" 

wget https://github.com/spiffe/spire/releases/download/v0.12.1/spire-extras-0.12.1-linux-x86_64-glibc.tar.gz -P /tmp 

cd /tmp && sudo tar zvxf spire-extras-0.12.1-linux-x86_64-glibc.tar.gz

echo "Starting OIDC provider" 

cd /tmp/spire-extras-0.12.1/bin && nohup ./oidc-discovery-provider -config /tmp/oidc-discovery-provider.conf &

sleep 10


