#!/bin/bash

my_dir="$(dirname $0)"
source "${my_dir}/utils.sh"

docker-ansible-playbook -b -i /inventory/hosts.yml --user ${USER} --private-key /root/.ssh/id_rsa /inventory/dummy-extranet.yml
