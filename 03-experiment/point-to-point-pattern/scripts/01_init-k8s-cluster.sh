#!/bin/sh
set -e
cd `dirname $0`

IPADDR=$(ip address show eth1 | grep inet | grep -v inet6 | awk '{print $2}' | cut -f1 -d/)
HOSTNAME=$(hostname -s)

# Stand Up Kubernetes Cluster
kubeadm init \
  --apiserver-advertise-address=$IPADDR \
  --apiserver-cert-extra-sans=$IPADDR \
  --node-name $HOSTNAME \
  --pod-network-cidr=192.168.0.0/16

# Configure Authentication to k8s master
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown vagrant:vagrant $HOME/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf
sleep 5s
kubeadm token create --print-join-command > $HOME/kubeadm_join_cmd.sh
chmod +x $HOME/kubeadm_join_cmd.sh
sed -i "/^[^#]*PasswordAuthentication[[:space:]]no/c\PasswordAuthentication yes" /etc/ssh/sshd_config
systemctl restart sshd
