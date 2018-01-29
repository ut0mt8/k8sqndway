
# Kubernetes The Quick and Dirty Way

This tutorial is a derivative of Kubernetes the hard way from the excellent Kelsey Hightower. This is pretty much the same setup except the boring crypto and authorisation stuff, agnostic to the underlying platform (non GCE specific), and directly using docker without CRI.

> The results of this tutorial should not be viewed as production ready ! but it can help you how to quickly setup a fully functional *but unsecure* cluster for educational purpose.

## Target Audience

As the original the target audience for this tutorial is someone planning to support a production Kubernetes cluster and wants to understand how everything fits together, but also for someone who think that securing all the things in a internal platform is overkill.

## Cluster Details

Kubernetes The Quick and Dirty Way guides you through bootstrapping a highly available Kubernetes cluster with *no* encryption between components and *no* authentication.

* [Kubernetes](https://github.com/kubernetes/kubernetes) 1.9.0
* [CNI Container Networking](https://github.com/containernetworking/cni) 0.6.0
* [etcd](https://github.com/coreos/etcd) 3.2.11

## Tables of contents

* [Prerequisites](docs/01-prerequisites.md)
* [Bootstrapping the etcd Cluster](docs/02-bootstrapping-etcd.md)
* [Bootstrapping the Kubernetes Control Plane](docs/03-bootstrapping-kubernetes-controllers.md)
* [Bootstrapping the Kubernetes Worker Nodes](docs/04-bootstrapping-kubernetes-workers.md)
* [Provisioning Pod Network Routes](docs/05-pod-network-routes.md)
* [Deploying the DNS Cluster Add-on](docs/06-dns-addon.md)
* [Smoke Test](docs/07-smoke-test.md)

* [Bonus: Using Flannel for the Network](docs/08-xtra-pod-network-flannel.md)
