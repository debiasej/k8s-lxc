#!/bin/bash -eo

## Variables
PRIMARY_MASTER_NAME=kmaster0
LOAD_BALANCER_ENDPOINT="10.163.23.155:6443"
POD_NETWORK_CIDR=10.244.0.0/16
CERT_PATHS="
/etc/kubernetes/pki/ca.crt
/etc/kubernetes/pki/ca.key
/etc/kubernetes/pki/sa.key            
/etc/kubernetes/pki/sa.pub
/etc/kubernetes/pki/front-proxy-ca.crt
/etc/kubernetes/pki/front-proxy-ca.key"

## Aux functions
title () {
  printf "\033[1;34m$*\033[0;0m\n"
}

## Install Docker, Kubernetes and additional packages
apt-get update && apt-get install -y wget
wget -qO - https://raw.githubusercontent.com/debiasej/k8s-lxc/master/ubuntu-cluster/ubuntu-k8s-base.sh | bash

##############################################
# To be executed only on PRIMARY master node #
##############################################

if [[ $(hostname) == $PRIMARY_MASTER_NAME ]]
then

  # Initialize Kubernetes
  title "[TASK 9] Initialize Kubernetes Cluster"
  # LOAD_BALANCER_ENDPOINT has the address ip or DNS and port of the load balancer (e.g. 10.163.23.155:6443)
  kubeadm init --pod-network-cidr=$POD_NETWORK_CIDR --control-plane-endpoint=$LOAD_BALANCER_ENDPOINT 2>&1 | tee /root/kubeinit.log

  # Copy Kube admin config
  title "[TASK 10] Copy kube admin config to root user .kube directory"
  mkdir /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config

  # Deploy flannel network
  title "[TASK 11] Deploy flannel network"
  # For Kubernetes v1.7+
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

  # Generate Cluster join command for master nodes
  title "[TASK 12] Generate and save cluster join command to /join-master-node.sh"
  TOKEN_CMD=$(kubeadm token create --print-join-command)
  echo "$TOKEN_CMD --control-plane" > /join-master-node.sh

  # Generate Cluster join command for worker nodes
  title "[TASK 13] Generate and save cluster join command to /join-worker-node.sh"
  echo $TOKEN_CMD > /join-worker-node.sh

fi

##################################################################
# To be executed only on master node but not on the primary node #
##################################################################

if [[ $(hostname) != $PRIMARY_MASTER_NAME && $(hostname) =~ .*master.* ]]
then

  # Get certificates from primary master node
  title "[TASK 9] Certificate distribution:"   
  mkdir -p /etc/kubernetes/pki/etcd

  echo "fetching certs from primary master node: $PRIMARY_MASTER_NAME"
  for file in $CERT_PATHS; do
  
    echo "fetching $file..."
    sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $PRIMARY_MASTER_NAME.lxd:$file /etc/kubernetes/pki/
 
  done

  echo "fetching /etc/kubernetes/pki/etcd/ca.crt..."
  sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $PRIMARY_MASTER_NAME.lxd:/etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/
  echo "fetching /etc/kubernetes/pki/etcd/ca.key..."
  sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $PRIMARY_MASTER_NAME.lxd:/etc/kubernetes/pki/etcd/ca.key /etc/kubernetes/pki/etcd/

  # Join master nodes to the Kubernetes cluster
  title "[TASK 10] Join master node to Kubernetes Cluster"
  echo "this may take some time ..."
  # Copy joincluster script ignoring SSH Host Key Verification
  sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $PRIMARY_MASTER_NAME.lxd:/join-master-node.sh /join-master-node.sh 2>/tmp/join-master-node.log 
  bash /join-master-node.sh >> /tmp/join-master-node.log 2>&1

fi

#######################################
# To be executed only on worker nodes #
#######################################

if [[ $(hostname) =~ .*worker.* ]]
then

  # Join worker nodes to the Kubernetes cluster
  title "[TASK 9] Join worker node to Kubernetes Cluster"
  echo "this may take some time ..."
  # Copy joincluster script ignoring SSH Host Key Verification
  sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $PRIMARY_MASTER_NAME.lxd:/join-worker-node.sh /join-worker-node.sh 2>/tmp/join-worker-node.log
  bash /join-worker-node.sh >> /tmp/join-worker-node.log 2>&1

fi
