#!/bin/bash

## Install docker from Docker-ce repository
echo "[TASK 1] Install docker container engine"
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
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

# Restart  docker service
echo "[TASK 2] Restart docker service"
systemctl daemon-reload
systemctl restart docker

# Add apt repo file for Kubernetes
echo "[TASK 3] Add apt repo file for kubernetes"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >> /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Install Kubernetes
echo "[TASK 4] Install Kubernetes (kubeadm, kubelet and kubectl)"
apt-get update && apt-get install -y kubelet=1.18.2-00 kubeadm=1.18.2-00 kubectl=1.18.2-00
apt-mark hold kubelet kubeadm kubectl

# Start and Enable kubelet service
echo "[TASK 5] Enable and start kubelet service"
systemctl enable kubelet
echo 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' > /etc/default/kubelet # Add user-specified flags
systemctl start kubelet

# Install Openssh server
echo "[TASK 6] Install and configure ssh"
apt-get install -y ssh
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl enable sshd
systemctl enable sshd
systemctl start sshd

# Set Root password
echo "[TASK 7] Set root password"
echo "root:ubuntu" | sudo chpasswd

# Install additional required packages
echo "[TASK 8] Install additional packages"
#apt-get install sshpass
#yum install -y -q which net-tools sudo sshpass less

