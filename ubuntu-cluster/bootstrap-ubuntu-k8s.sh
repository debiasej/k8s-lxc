#!/bin/bash -eo

## Variables
MASTER_NAME=kmaster
POD_NETWORK_CIDR=10.244.0.0/16

## Aux functions
title () {
  printf "\033[1;34m$*\033[0;0m\n"
}

## Install Docker, Kubernetes and additional packages
apt-get update && apt-get install -y wget
wget -qO - https://raw.githubusercontent.com/debiasej/k8s-lxc/master/ubuntu-cluster/ubuntu-k8s-base.sh | bash

#######################################
# To be executed only on master nodes #
#######################################

if [[ $(hostname) =~ .*master.* ]]
then

  # Initialize Kubernetes
  title "[TASK 9] Initialize Kubernetes Cluster"
  kubeadm init --pod-network-cidr=$POD_NETWORK_CIDR 2>&1 | tee /root/kubeinit.log

  # Copy Kube admin config
  title "[TASK 10] Copy kube admin config to root user .kube directory"
  mkdir /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config

  # Deploy flannel network
  title "[TASK 11] Deploy flannel network"
  # For Kubernetes v1.7+
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

  # Generate Cluster join command
  title "[TASK 12] Generate and save cluster join command to /joincluster.sh"
  echo $(kubeadm token create --print-join-command) > /join-worker-node.sh

fi

#######################################
# To be executed only on worker nodes #
#######################################

if [[ $(hostname) =~ .*worker.* ]]
then

  # Join worker nodes to the Kubernetes cluster
  title "[TASK 9] Join node to Kubernetes Cluster"
  # Copy joincluster script ignoring SSH Host Key Verification
  sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $MASTER_NAME.lxd:/join-worker-node.sh /join-worker-node.sh 2>/tmp/join-worker-node.log
  bash /join-worker-node.sh >> /tmp/join-worker-node.log 2>&1

fi

