# Bootstrapping the Kubernetes Worker Nodes

In this section you will bootstrap three Kubernetes worker nodes. The following components will be installed on each node: Nginx, Docker, [container networking plugins](https://github.com/containernetworking/cni),  [kubelet](https://kubernetes.io/docs/admin/kubelet), and [kube-proxy](https://kubernetes.io/docs/concepts/cluster-administration/proxies).

## Prerequisites

The commands in this section must be run on each worker vm: `wrk1`, `wrk2`, and `wrk3`.

## Provisioning a Kubernetes Worker Node

### Prerequesite

Ensure that bridge-netfilter module is loaded and enabled. (if not service will not work correctly and cni does not enable it by default)

```
sudo modprobe bridge-netfilter
sudo sysctl net.bridge.bridge-nf-call-iptables=1
```

Make it persistent the way your distribution want.

Install the OS dependencies (socat).

> The socat binary enables support for the `kubectl port-forward` command.

### Install and configure nginx 

In our setup we use nginx as an internal load balancer on the worker itself to ensure high avaibility connectivity to the master nodes.

Install a recent nginx with stream support the way you want. Update its config:


```
cat > nginx.conf <<EOF
worker_processes  1;

error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
  worker_connections  1024;
}

stream {
  upstream apiservers {
    server 10.0.0.1:8080;
    server 10.0.0.2:8080;
    server 10.0.0.3:8080;
  }

  server {
    listen 8080;
    proxy_pass apiservers;
  }
}
EOF
```

```
sudo mv nginx.conf /etc/nginx/nginx.conf

```
sudo systemctl enable nginx
```
```

```
sudo systemctl start nginx
```

### Install docker

Install docker following the docker site instructions for your distribution.
At time writing this is docker-ce-17.12.0. This should be OK.

We need to modify the docker.service in order to work with Kubernetes:

```
cat > docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com

[Service]
Type=notify
ExecStart=/usr/bin/dockerd --iptables=false --ip-masq=false --host=unix:///var/run/docker.sock --storage-driver=overlay
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
```


### Download and Install Worker Binaries

```
wget https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz \
  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubelet

```

Create the installation directories:

```
sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes
```

Install the worker binaries:

```
sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
```

```
chmod +x kubectl kube-proxy kubelet
```

```
sudo mv kubectl kube-proxy kubelet /usr/local/bin/
```

### Configure CNI Networking

We choose an arbitrary Pod CIDR range for the each worker node. For this lab we use static allocation for each worker node.

- wrk1 : 10.200.10.0/24
- wrk2 : 10.200.20.0/24
- wrk3 : 10.200.30.0/24

Create the `bridge` network configuration file and replace POD_CIDR with the correct value for the current worker node:

```
cat > 10-bridge.conf <<EOF
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "isDefaultGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "subnet": "POD_CIDR"
    }
}
EOF
```

Create the `loopback` network configuration file:

```
cat > 99-loopback.conf <<EOF
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF
```

Move the network configuration files to the CNI configuration directory:

```
sudo mv 10-bridge.conf 99-loopback.conf /etc/cni/net.d/
```

### Configure the Kubelet

Create the `kubelet.config` config file for kubelet:

```
cat > kube.config <<EOF
apiVersion: v1
clusters:
- cluster:
    server: http://127.0.0.1:8080
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: ""
  name: default
current-context: default
kind: Config
preferences: {}
users: []
EOF
```

```
sudo mv kube.config /var/lib/kubelet/kubeconfig
sudo cp /var/lib/kubelet/kubeconfig /var/lib/kube-proxy/kubeconfig
```

Create the `kubelet.service` systemd unit file:

```
cat > kubelet.service <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --allow-privileged=true \\
  --authorization-mode=AlwaysAllow \\
  --cloud-provider= \\
  --cluster-dns=10.32.0.10 \\
  --cluster-domain=cluster.local \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --pod-cidr=${POD_CIDR} \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Proxy

Create the `kube-proxy.service` systemd unit file:

```
cat > kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --cluster-cidr=10.200.0.0/16 \\
  --kubeconfig=/var/lib/kube-proxy/kubeconfig \\
  --proxy-mode=iptables \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the Worker Services

```
sudo mv docker.service kubelet.service kube-proxy.service /etc/systemd/system/
```

```
sudo systemctl daemon-reload
```

```
sudo systemctl enable docker kubelet kube-proxy
```

```
sudo systemctl start docker kubelet kube-proxy
```

> Remember to run the above commands on each worker node: `wrk1`, `wrk2`, and `wrk3`.

## Verification

Login to one of the controller nodes.

List the registered Kubernetes nodes:

```
kubectl get nodes -o wide
```

> output

```
NAME      STATUS    ROLES     AGE       VERSION   EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION              CONTAINER-RUNTIME
wrk1      Ready     <none>    12s       v1.9.0    <none>        CentOS Linux 7 (Core)   3.10.0-693.5.2.el7.x86_64   docker://17.12.0-ce
wrk2      Ready     <none>    12s       v1.9.0    <none>        CentOS Linux 7 (Core)   3.10.0-693.5.2.el7.x86_64   docker://17.12.0-ce
wrk3      Ready     <none>    13s       v1.9.0    <none>        CentOS Linux 7 (Core)   3.10.0-693.5.2.el7.x86_64   docker://17.12.0-ce
```
