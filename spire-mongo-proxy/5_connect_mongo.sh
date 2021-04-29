#!/bin/bash -xeu
set -o pipefail
pod=`kubectl get pods -l app.kubernetes.io/component=mongodb --no-headers -o name`
kubectl exec -it $pod -- mongo admin --host spire-envoy-tcp 


