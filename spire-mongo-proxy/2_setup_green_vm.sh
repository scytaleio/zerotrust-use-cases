#!/bin/bash -xeu
set -o xtrace
set -o pipefail

source environment

# This is passed straight into the agent conf file
# Needs to NOT start with spiffe://
TRUST_DOMAIN="test.com"

which openssl || (echo "openssl not found"; exit 1)
which vagrant || (echo "vagrant not found"; exit 1)

cmds/get_trust_bundle.sh > spire_bootstrap.tmp

pushd green_vm
vagrant destroy -f
vagrant up

# install useful utilities
yum install -y nc vim lsof

# First, set up OpenSSL just for testing connectivity
# This opens up a port with a self-signed cert on port 44330 just for testing purposes
vagrant ssh -- "echo test| openssl s_server -key key.pem -cert cert.pem -accept 44330 -www" &
sleep 10

# Make sure we can access port 44330 over TLS
# If we can't do this, there's no way Envoy will ever work
echo Q | openssl s_client localhost:44330
if [[ $? -ne 0 ]]; then
        echo "Failed to establish TLS connectivity with a test client/server"
        exit 1
fi

# Now we run an SSH service in the background to forward the SPIRE port into Kubernetes
nohup vagrant ssh -- -R 8081:$SPIRE_SERVER_IP:8081 -N &

# Set up a registration entry
# For now, just set up the root user to get a spiffe id test.com/green_vm
../cmds/add_backend_registration_entry_unix.sh
# It's not enough to check for success because the entry might have already existed 
CERTS=`cmds/show_registration_entries.sh  | grep "spiffe://test.com/backend"`
if [[ CERTS == "" ]]; then
        echo "Failed to create the registration entry"
        exit 1
fi

# Next, we set up SPIRE itself, using the install_spire script that is installed as 
# part of the VM.
vagrant ssh -- sudo bash install_spire.sh ${TRUST_DOMAIN} localhost 8081 $(../cmds/generate_join_token.sh)
if [[ $? -ne 0 ]]; then
        echo "Failed to install SPIRE"
        exit 1
fi

# Finally, install Envoy
vagrant ssh -- sudo bash install_envoy.sh spiffe://test.com/ns/default/sa/spire-envoy-tcp 20001 27017
if [[ $? -ne 0 ]]; then
        echo "Failed to install Envoy"
        exit 1
fi
sleep 10 # it takes quite a while for envoy to load

# Run the dummy server in the background
vagrant ssh -- "nohup bash dummy_server.sh > /dev/null 2>&1 < /dev/null &"
sleep 1
# Verify that the dummy server on port 27017 is accessible from inside the VM
# (It is not exposed outside the VM)
vagrant ssh -- nc -z localhost 27017
if [[ $? -ne 0 ]]; then
       echo "Failed to connect to the local dummy server"
       exit 1
fi

# Get a svid to verify SPIRE is working
# This SVID will only work for 4 hours but is good for a quick test
vagrant ssh -- mkdir /tmp/svid
vagrant ssh -- sudo /opt/spire/bin/spire-agent api fetch -write /tmp/svid/ -socketPath /var/run/spire/sockets/agent.sock
if [[ $? -ne 0 ]]; then
        echo "Failed to get an SVID"
        exit 1
fi

# Verify that connections to Envoy are working
vagrant ssh -- sudo openssl s_client -connect :20001 -cert /tmp/svid/svid.0.pem -key /tmp/svid/svid.0.key -CAfile /tmp/svid/bundle.0.pem -debug
if [[ $? -ne 0 ]]; then
        echo "Failed to connect securely to the local envoy"
        exit 1
fi

