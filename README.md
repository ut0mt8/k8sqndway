# Kubernetes The Quick and Dirty Way

This tutorial is a derivative of Kubernetes the hard way from the excellent Kelsey Hightower. This is pretty the same setup except the boring crypto and authorisation stuff, the fact that is not GCE opinionated, and directly using docker without CRI.

> The results of this tutorial should not be viewed as production ready ! but it can help you how to quickly setup a fully functional *but unsecure* cluster for educational purpose.

## Target Audience

As the original the target audience for this tutorial is someone planning to support a production Kubernetes cluster and wants to understand how everything fits together, but also for someone who think that securing all the things in a internal platform is overkill.

## Cluster Details

Kubernetes The Quick and Dirty Way guides you through bootstrapping a highly available Kubernetes cluster with *no* encryption between components and *no* authentication.

* [Kubernetes](https://github.com/kubernetes/kubernetes) 1.9.0
* [CNI Container Networking](https://github.com/containernetworking/cni) 0.6.0
* [etcd](https://github.com/coreos/etcd) 3.2.11


---

# Prerequisites

This tutorial assumes you have access to some kind of compute platform. AWS, GCE, Azure or your own private cloud should work.

We need a least 6 amd64 nodes with a flat network and no firewall between them (and no antispoofing activated, think of it if you use AWS). We will use fixed private IP on each node. External access can be good to test our stuff end to end but not necessary.


### Kubernetes Controllers

You can use whatever linux distros you want. (I made this lab with centos7 because it is what we use in our production environment, but Ubuntu/Debian should also be OK)

Create three nodes which will host the Kubernetes control plane with some resources (1Vcpu, 4Go ram, some disk), and let say we name them :

- ctl1, 10.0.0.1
- ctl2, 10.0.0.2
- ctl3, 10.0.0.3

### Kubernetes Workers

Each worker nodes requires a pod subnet allocation from the Kubernetes cluster CIDR range. The pod subnet allocation will be used to configure container networking in a later exercise.

> The Kubernetes cluster CIDR range is defined by the Controller Manager's `--cluster-cidr` flag. In this tutorial the cluster CIDR range will be set to `10.200.0.0/16`, which supports 254 subnets.

Create three nodes which will host the Kubernetes workers and give them a bit more resources (2Vcpu, 8G ram, some disk) and let say we name them :

- wrk1, 10.0.0.11
- wrk2, 10.0.0.12
- wrk3, 10.0.0.13

---

# Bootstrapping the etcd Cluster

Kubernetes components are stateless and store cluster state in [etcd](https://github.com/coreos/etcd). In this lab you will bootstrap a three nodes etcd cluster and configure it for high availability and *unsecure* remote access.

## Prerequisites

The commands in this lab must be run on each controller node: `ctrl1`, `ctrl2`, and `ctrl3`. Login to each controller node using ssh.

## Bootstrapping an etcd Cluster Member

### Download and Install the etcd Binaries

(Install wget if not already installed.)
Download the official etcd release binaries from the [coreos/etcd](https://github.com/coreos/etcd) GitHub project:

```
wget "https://github.com/coreos/etcd/releases/download/v3.2.11/etcd-v3.2.11-linux-amd64.tar.gz"
```

Extract and install the `etcd` server and the `etcdctl` command line utility:

```
tar -xvf etcd-v3.2.11-linux-amd64.tar.gz
```

```
sudo mv etcd-v3.2.11-linux-amd64/etcd* /usr/local/bin/
```

### Configure the etcd Server

```
sudo mkdir -p /etc/etcd /var/lib/etcd
```

Each etcd member must have a unique name within an etcd cluster. Set the etcd name to match the hostname of the current node and its private IP :

```
ETCD_NAME=$(hostname -s)
```

Create the `etcd.service` systemd unit file:

```
cat > etcd.service <<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --initial-advertise-peer-urls http://${INTERNAL_IP}:2380 \\
  --listen-peer-urls http://${INTERNAL_IP}:2380 \\
  --listen-client-urls http://${INTERNAL_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls http://${INTERNAL_IP}:2379 \\
  --initial-cluster ctrl1=http://10.0.0.1:2380,ctrl2=http://10.0.0.2:2380,ctrl3=http://10.0.0.3:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the etcd Server

```
sudo mv etcd.service /etc/systemd/system/
```

```
sudo systemctl daemon-reload
```

```
sudo systemctl enable etcd
```

```
sudo systemctl start etcd
```

> Remember to run the above commands on each controller vm: `ctl1`, `ctl2`, and `ctl3`.

## Verification

List the etcd cluster members (on any controller vm):

```
ETCDCTL_API=3 etcdctl member list
```

> output

```
885d39f23735e385, started, ctl2, http://10.0.0.2:2380, http://10.0.0.2:2379
9c41b374fd2f0a23, started, ctl1, http://10.0.0.1:2380, http://10.0.0.1:2379
c3714509dde986c4, started, ctl3, http://10.0.0.3:2380, http://10.0.0.3:2379
```

---
# Bootstrapping the Kubernetes Control Plane

In this section you will bootstrap the Kubernetes control plane across three nodes and configure it for high availability. The following components will be installed on each node: Kubernetes API Server, Scheduler, and Controller Manager.

## Prerequisites

The commands in this lab must be run on each controller instance: `ctl1`, `ctl2`, and `ctl3`. Login to each controller instance using ssh.

## Provision the Kubernetes Control Plane

### Download and Install the Kubernetes Controller Binaries

Download the official Kubernetes release binaries:

```
wget "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.9.0/bin/linux/amd64/kubectl"
```

Install the Kubernetes binaries:

```
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
```

```
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
```

### Configure the Kubernetes API Server

```
sudo mkdir -p /var/lib/kubernetes/
```


The node internal IP address will be used advertise the API Server to members of the cluster.

Create the `kube-apiserver.service` systemd unit file:

```
cat > kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --authorization-mode=AlwaysAllow \\
  --bind-address=0.0.0.0 \\
  --etcd-servers=http://10.0.0.1:2379,http://10.0.0.2:2379,http://10.0.0.3:2379 \\
  --insecure-bind-address=0.0.0.0 \\
  --runtime-config=api/all \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Controller Manager

Create the `kube-controller-manager.service` systemd unit file:

```
cat > kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --leader-elect=true \\
  --master=http://127.0.0.1:8080 \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Configure the Kubernetes Scheduler

Create the `kube-scheduler.service` systemd unit file:

```
cat > kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --leader-elect=true \\
  --master=http://127.0.0.1:8080 \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

### Start the Controller Services

```
sudo mv kube-apiserver.service kube-scheduler.service kube-controller-manager.service /etc/systemd/system/
```

```
sudo systemctl daemon-reload
```

```
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
```

```
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
```

> Allow up to 10 seconds for the Kubernetes API Server to fully initialize.

### Verification

```
kubectl get componentstatuses
```

```
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-2               Healthy   {"health": "true"}
etcd-0               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}
```

> Remember to run the above commands on each controller node: `ctl1`, `ctl2`, and `clt3`.


---
# Bootstrapping the Kubernetes Worker Nodes

In this lab you will bootstrap three Kubernetes worker nodes. The following components will be installed on each node: [runc](https://github.com/opencontainers/runc), [container networking plugins](https://github.com/containernetworking/cni),  [kubelet](https://kubernetes.io/docs/admin/kubelet), and [kube-proxy](https://kubernetes.io/docs/concepts/cluster-administration/proxies).

## Prerequisites

The commands in this lab must be run on each worker vm: `wrk1`, `wrk2`, and `wrk3`.

## Provisioning a Kubernetes Worker Node

Ensure that bridge-netfilter module is loaded and enabled. (if not service will not work correctly and cni do not enable it by default)

```
sudo modprobe bridge-netfilter
sudo sysctl net.bridge.bridge-nf-call-iptables = 1
```

Make it persistent the way your distro want.

Install the OS dependencies (socat).

> The socat binary enables support for the `kubectl port-forward` command.

Install docker following the docker site instructions for your distro.
At time writing this is docker-ce-17.12.0. This should be ok.

We need to modify the docker.service in order to work with Kubernetes:

```
cat > docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd --iptables=false --ip-masq=false --host=unix:///var/run/docker.sock --storage-driver=overlay
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

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

We choose an arbitrary Pod CIDR range for the each worker node. For this lab we use static allocation.

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
    server: http://${MASTER_IP}:8080
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
  --runtime-request-timeout=15m \\
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

---
# Provisioning Pod Network Routes

Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network.

In this lab you will create a route for each worker node that maps the node's Pod CIDR range to the node's internal IP address, aka static networking mode.

> There are [other ways](https://kubernetes.io/docs/concepts/cluster-administration/networking/#how-to-achieve-this) to implement the Kubernetes networking model. Most common are using Flannel, Calico or Kube-router.

## The Routing Table

Giving the allocation we made earlier:

```
- wrk1 : 10.200.10.0/24
- wrk2 : 10.200.20.0/24
- wrk3 : 10.200.30.0/24
```

## Routes

Create network routes for each worker and controller nodes:

```
ip route add 10.200.10.0/24 via 10.0.0.11
ip route add 10.200.20.0/24 via 10.0.0.12
ip route add 10.200.30.0/24 via 10.0.0.13
```

> You can make these persistent, the method depend on your chosen distro.

---
# Deploying the DNS Cluster Add-on

In this lab you will deploy the [DNS add-on](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) which provides DNS based service discovery to applications running inside the Kubernetes cluster.

## The DNS Cluster Add-on

Deploy the `kube-dns` cluster add-on (this is a simplified definition of kube-dns)

```
kubectl create -f kube-dns.yaml
```

> output

```
service "kube-dns" created
deployment "kube-dns" created
```

List the pods created by the `kube-dns` deployment:

```
kubectl get pods -l k8s-app=kube-dns -n kube-system
```

> output

```
NAME                        READY     STATUS    RESTARTS   AGE
kube-dns-3097350089-gq015   3/3       Running   0          20s
kube-dns-3097350089-q64qc   3/3       Running   0          20s
```

## Verification

Create a `busybox` deployment:

```
kubectl run busybox --image=busybox --command -- sleep 3600
```

List the pod created by the `busybox` deployment:

```
kubectl get pods -l run=busybox
```

> output

```
NAME                       READY     STATUS    RESTARTS   AGE
busybox-2125412808-mt2vb   1/1       Running   0          15s
```

Retrieve the full name of the `busybox` pod:

```
POD_NAME=$(kubectl get pods -l run=busybox -o jsonpath="{.items[0].metadata.name}")
```

Execute a DNS lookup for the `kubernetes` service inside the `busybox` pod:

```
kubectl exec -ti $POD_NAME -- nslookup kubernetes
```

> output

```
Server:    10.32.0.10
Address 1: 10.32.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.32.0.1 kubernetes.default.svc.cluster.local
```

---
# Smoke Test

In this lab you will complete a series of tasks to ensure your Kubernetes cluster is functioning correctly.


## Deployments

In this section you will verify the ability to create and manage [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).

Create a deployment for the [nginx](https://nginx.org/en/) web server, on one controller node:

```
kubectl run nginx --image=nginx
```

List the pod created by the `nginx` deployment:

```
kubectl get pods -l run=nginx
```

> output

```
NAME                     READY     STATUS    RESTARTS   AGE
nginx-4217019353-b5gzn   1/1       Running   0          15s
```

### Logs

In this section you will verify the ability to [retrieve container logs](https://kubernetes.io/docs/concepts/cluster-administration/logging/).

Print the `nginx` pod logs:

```
kubectl logs $POD_NAME
```

> output

```
127.0.0.1 - - [18/Dec/2017:14:50:36 +0000] "HEAD / HTTP/1.1" 200 0 "-" "curl/7.54.0" "-"
```

### Exec

In this section you will verify the ability to [execute commands in a container](https://kubernetes.io/docs/tasks/debug-application-cluster/get-shell-running-container/#running-individual-commands-in-a-container).

Print the nginx version by executing the `nginx -v` command in the `nginx` container:

```
kubectl exec -ti $POD_NAME -- nginx -v
```

> output

```
nginx version: nginx/1.13.7
```

## Services

In this section you will verify the ability to expose applications using a [Service](https://kubernetes.io/docs/concepts/services-networking/service/).

Expose the `nginx` deployment using a [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport) service:

```
kubectl expose deployment nginx --port 80 --type NodePort
```

Retrieve the node port assigned to the `nginx` service:

```
NODE_PORT=$(kubectl get svc nginx \
  --output=jsonpath='{range .spec.ports[0]}{.nodePort}')
```

Retrieve the external IP address of a worker instance:

```
```

Make an HTTP request using the external IP address and the `nginx` node port:

```
curl -I http://${EXTERNAL_IP}:${NODE_PORT}
```

> output

```
HTTP/1.1 200 OK
Server: nginx/1.13.7
Date: Mon, 18 Dec 2017 14:52:09 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 21 Nov 2017 14:28:04 GMT
Connection: keep-alive
ETag: "5a1437f4-264"
Accept-Ranges: bytes
```
---

