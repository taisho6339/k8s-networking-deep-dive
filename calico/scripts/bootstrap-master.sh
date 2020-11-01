#!/bin/sh
set -e
cd `dirname $0`

sudo sh ./00_configure.sh
sudo sh ./01_init-k8s-cluster.sh
sudo sh ./02_install-calico-master.sh
sudo sh ./03_install-calico-typha.sh
sudo sh ./04_install-calico-node.sh