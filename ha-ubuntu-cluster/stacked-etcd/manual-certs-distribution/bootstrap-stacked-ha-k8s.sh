#!/bin/bash -eo

## Install Docker, Kubernetes and additional packages
source ../../bootstrap-k8s-base.sh

## Variables
LOAD_BALANCER_ENDPOINT="10.163.23.155:6443"
PRIMARY_MASTER_NAME="kmaster"

##############################################
# To be executed only on PRIMARY master node #
##############################################

if [[ $(hostname) == $PRIMARY_MASTER_NAME ]]
then

  # Initialize Kubernetes
  title "[TASK 9] Initialize Kubernetes Cluster"
  # LOAD_BALANCER_ENDPOINT has the address ip or DNS and port of the load balancer (e.g. 10.163.23.155:6443)
  kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint "$LOAD_BALANCER_ENDPOINT" --upload-certs 2>&1 | tee /root/kubeinit.log

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
  sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $PRIMARY_MASTER_NAME.lxd:/join-worker-node.sh /join-worker-node.sh 2>/tmp/join-worker-node.log
  bash /join-worker-node.sh >> /tmp/join-worker-node.log 2>&1

fi

