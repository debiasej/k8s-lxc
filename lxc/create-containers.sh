#!/bin/bash

lxc launch images:ubuntu/16.04 kmaster --profile k8s
lxc launch images:ubuntu/16.04 kworker --profile k8s
