#!/bin/bash
kind export kubeconfig --name=blue
kubectl exec -n spire -it spire-server-0 -c spire-server -- bin/spire-server entry show -registrationUDSPath /run/spire/sockets/registration.sock
