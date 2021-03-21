#!/bin/bash
#
# all-nodes.sh
#
# This script will configure and provision for Kubernetes, all nodes
# after update, upgrade, hostname change, and reboot.
#

# install docker
sudo apt-get update && sudo apt install -y docker.io

# configure cgroup driver to be systemd
sudo cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# now append memory and swap options to the end of cmdline.txt
sudo sed -i '$ s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1/' /boot/firmware/cmdline.txt

# Kubernetes recommends iptables and iptables6 set for bridged-network traffic
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

# now activate
sudo sysctl --system

# add Google's repo key (packages.cloud.google.com)
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# add the Kubernetes repo to our list of repos
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# now install Kubernetes, kubelet, kubeadm, and kubectl
sudo apt update && sudo apt install -y kubelet kubeadm kubectl


