#!/bin/bash

nodes=()
for x in $(lxc list | grep -E 'master|worker' | awk -F'|' {'print $2'}); do
  nodes+=("$x")
done

if [ ${#nodes[@]} -eq 0 ]; then
  echo "There aren't any node avaiable to remove"
  exit 0
fi

echo "Do you want to remove the following nodes? (Y/n)"
echo ${nodes[@]}

read -p "" confirm && [[ $confirm == [Y] ]] || exit 1

for node in ${nodes[@]}; do
 echo "Removing $node........."
 lxc delete -f $node
done
