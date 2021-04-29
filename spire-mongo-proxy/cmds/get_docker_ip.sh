#!/bin/bash

if [[ $1 == "" ]]
then
	echo "Usage: $0 <container-name>"
	exit 1
fi

container_id=`docker container ls -a -q --filter "name=$1"`

if [[ $? != 0 ]]
then
	echo "Unable to find container named $1"
	exit 1
fi

ip_output=`docker exec -it $container_id /usr/sbin/ip addr show`

regex='(172.[0-9]*\.[0-9]*\.[0-9]*)'
if [[ $ip_output =~ $regex ]]
then
        ip="${BASH_REMATCH[1]}"
        echo $ip
        exit 0
else
        echo "Unexpected output from \"ip addr show\": $ip_output"
        exit 1
fi

