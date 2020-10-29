#!/bin/bash

# traffic that goes to a pod in worker-0 should be go to the worker-0 gateway
sudo route add -net 10.200.0.0 netmask 255.255.255.0 gw 10.163.23.165

# ip route show
