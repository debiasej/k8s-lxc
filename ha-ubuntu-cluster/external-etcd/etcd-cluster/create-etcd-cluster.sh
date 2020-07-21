#!/bin/bash -eo

## Aux functions
title () {
  printf "\033[1;34m$*\033[0;0m\n"
}

# Update HOST0, HOST1, and HOST2 with the IPs or resolvable names of your hosts
export HOST0=10.163.23.180
export HOST1=10.163.23.42
export HOST2=10.163.23.214
ETCD_NAMES=("etcd0" "etcd1" "etcd2")
PRIMARY_ETCD_NAME=${ETCD_NAMES[0]}

# Configure the kubelet to be a service manager for etcd
printf "\033[1;34m[TASK 9] Configure the kubelet to be a service manager for etcd\033[0;0m\n"
# Override kubeadm-provided kubelet unit file
cat << EOF > /etc/systemd/system/kubelet.service.d/20-etcd-service-manager.conf
[Service]
ExecStart=
#  Replace "systemd" with the cgroup driver of your container runtime. The default value in the kubelet is "cgroupfs".
ExecStart=/usr/bin/kubelet --address=127.0.0.1 --pod-manifest-path=/etc/kubernetes/manifests --cgroup-driver=systemd
Restart=always
EOF

systemctl daemon-reload
systemctl restart kubelet

############################################
# To be executed only on PRIMARY etcd node #
############################################

if [[ $(hostname) == $PRIMARY_ETCD_NAME ]]
then

# Create configuration files for kubeadm
printf "\033[1;34m[TASK 10] Generate configuration files for kubeadm for each etcd member\033[0;0m\n"

# Create temp directories to store files that will end up on other hosts.
mkdir -p /tmp/${HOST0}/ /tmp/${HOST1}/ /tmp/${HOST2}/

ETCD_HOSTS=(${HOST0} ${HOST1} ${HOST2})
NAMES=("infra0" "infra1" "infra2")

for i in "${!ETCD_HOSTS[@]}"; do
HOST=${ETCD_HOSTS[$i]}
NAME=${NAMES[$i]}
cat << EOF > /tmp/${HOST}/kubeadmcfg.yaml
apiVersion: "kubeadm.k8s.io/v1beta2"
kind: ClusterConfiguration
etcd:
    local:
        serverCertSANs:
        - "${HOST}"
        peerCertSANs:
        - "${HOST}"
        extraArgs:
            initial-cluster: ${NAMES[0]}=https://${ETCD_HOSTS[0]}:2380,${NAMES[1]}=https://${ETCD_HOSTS[1]}:2380,${NAMES[2]}=https://${ETCD_HOSTS[2]}:2380
            initial-cluster-state: new
            name: ${NAME}
            listen-peer-urls: https://${HOST}:2380
            listen-client-urls: https://${HOST}:2379
            advertise-client-urls: https://${HOST}:2379
            initial-advertise-peer-urls: https://${HOST}:2380
EOF
done

# Generate the certificate authority
printf "\033[1;34m[TASK 10] Generate the certificate authority\033[0;0m\n"
# This creates two files: /etc/kubernetes/pki/etcd/ca.crt and /etc/kubernetes/pki/etcd/ca.key
kubeadm init phase certs etcd-ca

# Create certificates for each member
printf "\033[1;34m[TASK 11] Create certificates for each member\033[0;0m\n"
kubeadm init phase certs etcd-server --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST2}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST2}/
# cleanup non-reusable certificates
find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

kubeadm init phase certs etcd-server --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST1}/kubeadmcfg.yaml
cp -R /etc/kubernetes/pki /tmp/${HOST1}/
find /etc/kubernetes/pki -not -name ca.crt -not -name ca.key -type f -delete

kubeadm init phase certs etcd-server --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs etcd-peer --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs etcd-healthcheck-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
kubeadm init phase certs apiserver-etcd-client --config=/tmp/${HOST0}/kubeadmcfg.yaml
# No need to move the certs because they are for HOST0

# clean up certs that should not be copied off this host
find /tmp/${HOST2} -name ca.key -type f -delete
find /tmp/${HOST1} -name ca.key -type f -delete

# Move certs and kubeadm configs
printf "\033[1;34m[TASK 12] Move certificates and kubeadm configs to their respective etcd nodes\033[0;0m\n"
for (( i=1; i<${#ETCD_NAMES[@]}; i++ )); do
  HOST=${ETCD_HOSTS[$i]}
  HOSTNAME=${ETCD_NAMES[$i]}
  echo "Move ${HOSTNAME} (${HOST}) certificates..."
  sshpass -p "ubuntu" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r /tmp/${HOST}/* ${HOSTNAME}.lxd:/tmp/ 2>/tmp/move-certs.log
done

# Generate a static pod manifest for primary etcd node
printf "\033[1;34m[TASK 13] Generate a static pod manifest for primary etcd node\033[0;0m\n"
kubeadm init phase etcd local --config=/tmp/${HOST0}/kubeadmcfg.yaml

fi

#################################################################
# To be executed only on etcd nodes but not on the primary node #
#################################################################

if [[ $(hostname) != $PRIMARY_ETCD_NAME && $(hostname) =~ .*etcd.* ]]
then
  
  # Move certs from /tmp/pki to /etc/kubernetes/pki
  printf "\033[1;34m[TASK 10] Move certs /tmp/pki to /etc/kubernetes/pki\033[0;0m\n"
  mv /tmp/pki /etc/kubernetes/

  # Generate a static pod manifest for etcd 
  printf "\033[1;34m[TASK 11] Generate a static pod manifest for etcd\033[0;0m\n"
  kubeadm init phase etcd local --config=/tmp/kubeadmcfg.yaml

fi
