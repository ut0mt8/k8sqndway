# Prerequisites

This tutorial assumes you have access to some kind of compute platform. AWS, GCE, Azure or your own private cloud should work.

We need a least 6 amd64 nodes with a flat network and no firewall between them (and no antispoofing activated, think of it if you use AWS). We will use fixed private IP on each node. External access can be good to test our stuff end to end but not mandatory.


### Kubernetes Controllers

You can use whatever linux distribution you want. (I use Centos7 because it is what we use in our production environment, but Ubuntu/Debian should also be OK)

Create three nodes which will host the Kubernetes control plane with some resources (1 vcpu, 4Go ram, some disk), and let say we name and address them :

- ctrl1, 10.0.0.1
- ctri2, 10.0.0.2
- ctrl3, 10.0.0.3

### Kubernetes Workers

Each worker nodes requires a pod subnet allocation from the Kubernetes cluster CIDR range. The pod subnet allocation will be used to configure container networking in a later exercise.

> The Kubernetes cluster CIDR range is defined by the Controller Manager's `--cluster-cidr` flag. In this tutorial the cluster CIDR range will be set to `10.200.0.0/16`, which supports 254 subnets.

Create three nodes which will host the Kubernetes workers and give them a bit more resources (2 vcpu, 8G ram, some disk) and let say we name and address them :

- wrk1, 10.0.0.11
- wrk2, 10.0.0.12
- wrk3, 10.0.0.13

