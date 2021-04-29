#!/bin/bash

subnet_output=`docker network inspect -f '{{.IPAM.Config}}' kind`
if [[ $? != 0 ]]
then
	echo "Unable to find subnet"
	exit 1
fi

regex='(172.[0-9]*\.)[0-9]*\.[0-9]*'
if [[ $subnet_output =~ $regex ]]
then
        ip="${BASH_REMATCH[1]}"
        echo $ip
        exit 0
else
        echo "Unexpected output from \"docker inspect\": $ip_output"
        exit 1
fi

