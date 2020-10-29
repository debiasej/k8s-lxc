
# Copy certs to instances root directory
for instance in worker-0; do
  lxc file push ca.pem ${instance}-key.pem ${instance}.pem ${instance}/root/
done

for instance in controller-0 controller-1; do
  lxc file push ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ${instance}/root/
done
