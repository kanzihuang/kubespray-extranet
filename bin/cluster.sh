#!/bin/bash

source "$(dirname $0)/utils.sh"

docker-ansible-playbook -b -i /inventory/hosts.yml --user ${USER} --private-key /root/.ssh/id_rsa /inventory/cluster.yml
