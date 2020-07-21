#!/bin/bash

HOST0=10.163.23.188
ETCD_TAG=$(kubeadm config images list --kubernetes-version 1.18.3 2>/dev/null | grep etcd | awk -F: '{print $NF}')

echo $ETCD_TAG
echo $HOST0

docker run --rm  \
--net host \
-v /etc/kubernetes:/etc/kubernetes k8s.gcr.io/etcd:${ETCD_TAG} etcdctl \
--cert /etc/kubernetes/pki/etcd/peer.crt \
--key /etc/kubernetes/pki/etcd/peer.key \
--cacert /etc/kubernetes/pki/etcd/ca.crt \
--endpoints https://${HOST0}:2379 endpoint health --cluster


