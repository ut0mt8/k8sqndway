#!/bin/bash

echo "PROVISIONNING..."

# Ensure selinux is disabled
sudo cp -f /tmp/config/selinux /etc/sysconfig/selinux

# Ensure br_netfilter is loaded at startup
sudo cp -f /tmp/config/br_netfilter.modules /etc/sysconfig/modules
sudo chmod +x /etc/sysconfig/modules/br_netfilter.modules

# Ensure net.bridge.bridge-nf-call-iptables=1
sudo cp -f /tmp/config/10-bridge-netfilter.conf /etc/sysctl.d/

# Install nginx repo
sudo cp -f /tmp/config/nginx.repo /etc/yum.repos.d/nginx.repo

# Upgrade all
sudo yum update -y

# Install nginx
sudo yum install -y nginx

# Copy configuration file
sudo cp -f /tmp/config/nginx.conf /etc/nginx/nginx.conf 

#Start Nginx service and enable to start on boot:
sudo systemctl enable nginx
sudo systemctl start nginx

# Install docker
sudo yum-config-manager --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

sudo yum install -y docker-ce

# Create some usefull directory
sudo mkdir -p \
  /etc/kube-flannel \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

# Download binaries
sudo yum install -y wget

cd /tmp/ && 
wget https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz 

cd /tmp/bin/
wget https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/{kube-proxy,kubelet}
wget https://github.com/coreos/flannel/releases/download/v0.8.0/flanneld-amd64 -O /tmp/bin/flannel

# Install binaries
sudo tar -xvf /tmp/cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
sudo mv /tmp/bin/* /usr/local/bin/
sudo chmod +x /usr/local/bin/*

# Install config files
sudo cp -f /tmp/config/10-flannel.conf /etc/cni/net.d/
sudo cp -f /tmp/config/99-loopback.conf /etc/cni/net.d/
sudo cp -f /tmp/config/kube.config /var/lib/kubelet/kubeconfig
sudo cp -f /tmp/config/kube.config /var/lib/kube-proxy/kubeconfig
sudo cp -f /tmp/config/net-conf.json /etc/kube-flannel/

# Enable service
sudo mv /tmp/config/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable docker flannel kubelet kube-proxy 
sudo systemctl start docker flannel kubelet kube-proxy

# Clean up /tmp
sudo rm -rf /tmp/*

echo "DONE"

