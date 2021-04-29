#!/bin/bash
kind export kubeconfig --name=blue

join_token_output=`kubectl exec -it spire-server-0 -n spire -c spire-server -- bin/spire-server token generate -spiffeID spiffe://test.com/green -registrationUDSPath /run/spire/sockets/registration.sock`

regex='Token: ([a-z0-9-]*)'
if [[ $join_token_output =~ $regex ]]
then
        join_token="${BASH_REMATCH[1]}"
        echo $join_token
	exit 0
else
        echo "Unexpected output from \"spire-server token generate\": $join_token_output"
	exit 1
fi

