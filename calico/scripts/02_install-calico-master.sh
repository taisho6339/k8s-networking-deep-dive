#!/bin/sh
set -e
cd `dirname $0`

export KUBECONFIG=$HOME/.kube/config
export DATASTORE_TYPE=kubernetes

# Congirue k8s as calico's datastore
kubectl apply -f https://docs.projectcalico.org/manifests/crds.yaml
wget https://github.com/projectcalico/calicoctl/releases/download/v3.14.0/calicoctl
chmod +x calicoctl
mv calicoctl /usr/local/bin/

# Congirue IPPools for Calico
cat > pool1.yaml <<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: pool1
spec:
  cidr: 192.168.0.0/18
  ipipMode: Never
  natOutgoing: true
  disabled: false
  nodeSelector: all()
EOF
cat > pool2.yaml <<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: pool2
spec:
  cidr: 192.168.192.0/19
  ipipMode: Never
  natOutgoing: true
  disabled: true
  nodeSelector: all()
EOF
calicoctl create -f pool1.yaml
calicoctl create -f pool2.yaml

# Install CNI Plugin of Calico
openssl req -newkey rsa:4096 \
           -keyout cni.key \
           -nodes \
           -out cni.csr \
           -subj "/CN=calico-cni"
openssl x509 -req -in cni.csr \
                  -CA /etc/kubernetes/pki/ca.crt \
                  -CAkey /etc/kubernetes/pki/ca.key \
                  -CAcreateserial \
                  -out cni.crt \
                  -days 365
chown vagrant:vagrant cni.crt
APISERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
kubectl config set-cluster kubernetes \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=$APISERVER \
    --kubeconfig=$HOME/cni.kubeconfig
kubectl config set-credentials calico-cni \
    --client-certificate=cni.crt \
    --client-key=cni.key \
    --embed-certs=true \
    --kubeconfig=$HOME/cni.kubeconfig
kubectl config set-context default \
    --cluster=kubernetes \
    --user=calico-cni \
    --kubeconfig=$HOME/cni.kubeconfig
kubectl config use-context default --kubeconfig=$HOME/cni.kubeconfig
chown vagrant:vagrant $HOME/cni.kubeconfig

kubectl apply -f - <<EOF
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: calico-cni
rules:
  # The CNI plugin needs to get pods, nodes, and namespaces.
  - apiGroups: [""]
    resources:
      - pods
      - nodes
      - namespaces
    verbs:
      - get
  # The CNI plugin patches pods/status.
  - apiGroups: [""]
    resources:
      - pods/status
    verbs:
      - patch
 # These permissions are required for Calico CNI to perform IPAM allocations.
  - apiGroups: ["crd.projectcalico.org"]
    resources:
      - blockaffinities
      - ipamblocks
      - ipamhandles
    verbs:
      - get
      - list
      - create
      - update
      - delete
  - apiGroups: ["crd.projectcalico.org"]
    resources:
      - ipamconfigs
      - clusterinformations
      - ippools
    verbs:
      - get
      - list
EOF
kubectl create clusterrolebinding calico-cni --clusterrole=calico-cni --user=calico-cni

## Install CNI Plugin
curl -L -o /opt/cni/bin/calico https://github.com/projectcalico/cni-plugin/releases/download/v3.14.0/calico-amd64
chmod 755 /opt/cni/bin/calico
curl -L -o /opt/cni/bin/calico-ipam https://github.com/projectcalico/cni-plugin/releases/download/v3.14.0/calico-ipam-amd64
chmod 755 /opt/cni/bin/calico-ipam

mkdir -p /etc/cni/net.d/
cp $HOME/cni.kubeconfig /etc/cni/net.d/calico-kubeconfig
chmod 600 /etc/cni/net.d/calico-kubeconfig

cat > /etc/cni/net.d/10-calico.conflist <<EOF
{
  "name": "k8s-pod-network",
  "cniVersion": "0.3.1",
  "plugins": [
    {
      "type": "calico",
      "log_level": "info",
      "datastore_type": "kubernetes",
      "mtu": 1500,
      "ipam": {
          "type": "calico-ipam"
      },
      "policy": {
          "type": "k8s"
      },
      "kubernetes": {
          "kubeconfig": "/etc/cni/net.d/calico-kubeconfig"
      }
    },
    {
      "type": "portmap",
      "snat": true,
      "capabilities": {"portMappings": true}
    }
  ]
}
EOF
