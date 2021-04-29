#!/bin/bash -eu
set -o pipefail

kind export kubeconfig --name=blue 2> /dev/null

kubectl exec -it spire-server-0 -n spire -c spire-server -- bin/spire-server bundle show -format pem -registrationUDSPath /run/spire/sockets/registration.sock

