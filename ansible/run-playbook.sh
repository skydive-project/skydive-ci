#!/bin/bash

dir="$(dirname "$0")"

ansible-galaxy install -r requirements.yml

export ANSIBLE_ROLES_PATH="~/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles:$dir/../../skydive/contrib/ansible/roles"

if [ "$1" = "master" ]
then
	ansible-playbook -i inventory.yml -t master -e deploy_master=true -e jenkins_public_ip=51.83.46.175 --skip-tags "vagrant,jenkins_slave_setup" -e ansible_python_interpreter=/usr/bin/python3 -e jenkins_public_hostname=ci.graffiti.community -e jenkins_admin_password=password deploy.yml
else if [ "$1" = "slave" ]
	ansible-playbook -i inventory.yml -t slave --skip-tags "vagrant,jenkins_slave_setup" -e ansible_python_interpreter=/usr/bin/python3 -e jenkins_public_hostname=ci.graffiti.community -e jenkins_admin_password=password deploy.yml
fi
