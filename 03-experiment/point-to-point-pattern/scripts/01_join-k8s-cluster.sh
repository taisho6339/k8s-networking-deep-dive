#!/bin/sh
set -e
cd `dirname $0`

apt-get install -y sshpass
sshpass -p "vagrant" scp -o StrictHostKeyChecking=no vagrant@192.168.254.10:/home/vagrant/kubeadm_join_cmd.sh .
sh ./kubeadm_join_cmd.sh