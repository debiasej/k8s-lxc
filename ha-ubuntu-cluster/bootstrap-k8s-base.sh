#!/bin/bash -eo

## Aux functions
title () {
  printf "\033[1;34m\033[0;0m\n"
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
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable"

# Install Docker CE.
apt-get update && apt-get install -y   containerd.io=1.2.13-1   docker-ce=5:19.03.8~3-0~ubuntu-xenial   docker-ce-cli=5:19.03.8~3-0~ubuntu-xenial

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
apt-get update && apt-get install -y kubelet=1.18.3-00 kubeadm=1.18.3-00 kubectl=1.18.3-00
apt-mark hold kubelet kubeadm kubectl

# Install additional required packages
title "[TASK 5] Install additional packages"
# Update the kernel image
apt-get install -y linux-image-4.15.0-101-generic sshpass
# Hack required to provision K8s v1.15+ in LXC containers. The container should be privileged.
mknod /dev/kmsg c 1 11

# Start and Enable kubelet service
title "[TASK 6] Enable and start kubelet service"
systemctl enable kubelet
# Add user-specified flags
echo 'KUBELET_EXTRA_ARGS="--cgroup-driver=systemd --runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice"' > /etc/default/kubelet
# Make hack permanent adding a ExecStartPre directive
sed -i 's/exit 0//' /etc/rc.local
echo $'mknod /dev/kmsg c 1 11\nexit0' >> /etc/rc.local
systemctl daemon-reload
systemctl restart kubelet

# Install Openssh server
title "[TASK 7] Install and configure ssh"
apt-get install -y ssh
sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl enable sshd
systemctl restart sshd

# Set Root password
title "[TASK 8] Set root password"
echo "root:ubuntu" | sudo chpasswd
