#!/bin/bash -eo

## Variables
PRIMARY_MASTER_NAME="kmaster0"
PRIMARY_ETCD_NAME="etcd0"
LOAD_BALANCER_ENDPOINT="10.163.23.155:6443"
POD_NETWORK_CIDR=10.244.0.0/16
ETCD_0_IP=10.163.23.55
ETCD_1_IP=10.163.23.228
ETCD_2_IP=10.163.23.214

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

  title "[TASK 9] Set up the primary control plane node"
  # Copy etcd certs from the primary etcd node 
  mkdir -p  /etc/kubernetes/pki/etcd
  sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $PRIMARY_ETCD_NAME.lxd:/etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/ca.crt
  sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $PRIMARY_ETCD_NAME.lxd:/etc/kubernetes/pki/apiserver-etcd-client.crt /etc/kubernetes/pki/apiserver-etcd-client.crt  
  sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $PRIMARY_ETCD_NAME.lxd:/etc/kubernetes/pki/apiserver-etcd-client.key /etc/kubernetes/pki/apiserver-etcd-client.key

# Create kubeadm config file
cat <<EOF > /kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "$LOAD_BALANCER_ENDPOINT"
etcd:
    external:
        endpoints:
        - https://$ETCD_0_IP:2379
        - https://$ETCD_1_IP:2379
        - https://$ETCD_2_IP:2379
        caFile: /etc/kubernetes/pki/etcd/ca.crt
        certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
        keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key
networking:
  podSubnet: "$POD_NETWORK_CIDR" # --pod-network-cidr
EOF

  # Initialize Kubernetes
  title "[TASK 10] Initialize Kubernetes Cluster"
  # LOAD_BALANCER_ENDPOINT has the address ip or DNS and port of the load balancer (e.g. 10.163.23.155:6443)
  kubeadm init --config=/kubeadm-config.yaml --upload-certs 2>&1 | tee /root/kubeinit.log

  # Copy Kube admin config
  title "[TASK 11] Copy kube admin config to root user .kube directory"
  mkdir /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config

  # Deploy flannel network
  title "[TASK 12] Deploy flannel network"
  # For Kubernetes v1.7+
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

  # Generate Cluster join command for master nodes
  title "[TASK 13] Generate and save cluster join command to /join-master-node.sh from kubeadm config"
  CERT_KEY=$(echo $(kubeadm init phase upload-certs --upload-certs --config /kubeadm-config.yaml) | awk '{print $(NF)}')
  echo $(kubeadm token create --certificate-key $CERT_KEY --print-join-command) > /join-master-node.sh

  # Generate Cluster join command for worker nodes
  title "[TASK 14] Generate and save cluster join command to /join-worker-node.sh"
  echo $(kubeadm token create --print-join-command) > /join-worker-node.sh

fi

##################################################################
# To be executed only on master node but not on the primary node #
##################################################################

if [[ $(hostname) != $PRIMARY_MASTER_NAME && $(hostname) =~ .*master.* ]]
then

 # Join master nodes to the Kubernetes cluster
 title "[TASK 9] Join master node to Kubernetes Cluster"
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
