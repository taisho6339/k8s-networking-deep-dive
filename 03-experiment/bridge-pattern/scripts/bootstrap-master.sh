#!/bin/sh
set -e
cd `dirname $0`

sudo sh ./00_configure.sh
sudo sh ./01_init-k8s-cluster.sh