#!/bin/bash

pod=`kubectl get pods -l app=sleep --no-headers -o name`
kubectl exec -it $pod -c sleep -- /usr/bin/curl spire-istio-envoy:443
