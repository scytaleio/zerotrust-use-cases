#!/bin/bash -xeu 
set -o pipefail



# First kill the dummy server that we started to set up Envoy
pushd green_vm
vagrant ssh -- "kill \`cat dummy_server_pid\`"
vagrant ssh -- pkill nc
sleep 10

vagrant ssh -- sudo cp mongodb-org-4.4.repo /etc/yum.repos.d/mongodb-org-4.4.repo

vagrant ssh -- sudo sudo yum install -y mongodb-org

vagrant ssh -- sudo systemctl start mongod

vagrant ssh -- nc -z localhost 27017
if [[ $? -ne 0 ]]; then
	echo "Failed to connect to mongod after initial installation"
	exit 1
fi


