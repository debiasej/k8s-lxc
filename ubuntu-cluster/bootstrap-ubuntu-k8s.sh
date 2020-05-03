#!/bin/bash

## Aux functions
title () {
  printf "\033[1;34m$*\033[0;0m\n"
}

## Install docker from Docker-ce repository
title "[TASK 1] Install docker container engine"
# Install Docker CE
# Set up the repository:
# Install packages to allow apt to use a repository over HTTPS
apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

# Add Docker apt repository.
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install Docker CE.
apt-get update && apt-get install -y \
  containerd.io=1.2.13-1 \
  docker-ce=5:19.03.8~3-0~ubuntu-$(lsb_release -cs) \
  docker-ce-cli=5:19.03.8~3-0~ubuntu-$(lsb_release -cs)

# Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart  docker service
title "[TASK 2] Restart docker service"
systemctl daemon-reload
systemctl restart docker

# Add apt repo file for Kubernetes
title "[TASK 3] Add apt repo file for kubernetes"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >> /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Install Kubernetes
title "[TASK 4] Install Kubernetes (kubeadm, kubelet and kubectl)"
#apt-get update && apt-get install -y kubelet=1.18.2-00 kubeadm=1.18.2-00 kubectl=1.18.2-00
apt-get update && apt-get install -y kubeadm-1.17.1 kubelet-1.17.1 kubectl-1.17.1
apt-mark hold kubelet kubeadm kubectl

# Start and Enable kubelet service
title "[TASK 5] Enable and start kubelet service"
systemctl enable kubelet
sed -i "s/\$KUBELET_EXTRA_ARGS/\$KUBELET_EXTRA_ARGS\ --cgroup-driver=systemd/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' > /etc/default/kubelet # Add user-specified flags
systemctl start kubelet

# Install Openssh server
title "[TASK 6] Install and configure ssh"
apt-get install -y ssh
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl enable sshd
systemctl restart sshd

# Set Root password
title "[TASK 7] Set root password"
echo "root:ubuntu" | sudo chpasswd

# Install additional required packages
title "[TASK 8] Install additional packages"
apt-get install -y linux-image-$(uname -r)
# Hack required to provision K8s v1.15+ in LXC containers
#mknod /dev/kmsg c 1 11
#chmod +x /etc/rc.d/rc.local
#echo 'mknod /dev/kmsg c 1 11' >> /etc/rc.d/rc.local

#######################################
# To be executed only on master nodes #
#######################################

if [[ $(hostname) =~ .*master.* ]]
then

  # Initialize Kubernetes
  title "[TASK 9] Initialize Kubernetes Cluster"
  kubeadm init --pod-network-cidr=10.63.200.0/24 2>&1 | tee /root/kubeinit.log

  # Copy Kube admin config
  title "[TASK 10] Copy kube admin config to root user .kube directory"
  mkdir /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config

  # Deploy flannel network
  title "[TASK 11] Deploy flannel network"
  # For Kubernetes v1.7+
  #kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

  # Generate Cluster join command
  title "[TASK 12] Generate and save cluster join command to /joincluster.sh"
  #echo $(kubeadm token create --print-join-command) > /join-worker-node.sh

fi

