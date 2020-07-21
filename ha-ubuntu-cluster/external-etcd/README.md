## Set up a cluster with external etcd nodes

It is similar to the procedure used for stacked etcd with the exception you should setup etcd cluster first, and youd should pass the etcd info in a kubeadm config file.

# Set up etcd cluster 

Go to the etcd-cluster folder and run the following scripts:
- Run `ubuntu-k8s-base.sh` on each of the etcd nodes starting with the prinary node, e.g. etcd0. This script install kubelet, docker and all common dependencies.
- After Docker and Kubelet has been installed on each etcd node. Run `create-etcd-cluster.sh` in the same way as before in order to install etcd certs, kubeadm config files and etcd static pods.

# Set up load balancer

As has been done before in the case of the stacked cluster. Run a haproxy with the correct control-plane node IP addresses. Set up the haproxy with the `haproxy.cfg` config file.

# Set up the control plane nodes
 
