#!/bin/bash -xeu
set -o pipefail
echo $$ > /home/vagrant/dummy_server_pid
while true; do echo "The time is" $(date) | nc -l 27017; done
