#!/bin/bash
kind export kubeconfig --name=blue
kubectl exec -n spire -it spire-server-0 -c spire-server --  \
   bin/spire-server entry create  \
      -parentID spiffe://test.com/green \
      -selector k8s:sa:spire-istio-envoy \
      -spiffeID spiffe://test.com/backend \
      -registrationUDSPath /run/spire/sockets/registration.sock
