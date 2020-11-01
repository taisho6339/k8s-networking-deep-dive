#!/bin/sh
set -e
cd `dirname $0`

apt update
apt install -y docker.io
systemctl enable docker

apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
swapoff -a

IPADDR=$(ip a show eth1 | grep inet | grep -v inet6 | awk '{print $2}' | cut -f1 -d/)
touch /etc/default/kubelet
chown vagrant:vagrant /etc/default/kubelet
echo "KUBELET_EXTRA_ARGS=--node-ip=$IPADDR" > /etc/default/kubelet
systemctl daemon-reload
systemctl restart kubelet