
# Kubernetes The Quick and Dirty Way

This tutorial is a derivative of Kubernetes the hard way from the excellent Kelsey Hightower. This is pretty the same setup except the boring crypto and authorisation stuff, agnostic to the underlying platform (non GCE specific), and directly using docker without CRI.

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
* [Provisioning Compute Resources](docs/02-compute-resources.md)
* [Bootstrapping the etcd Cluster](docs/03-bootstrapping-etcd.md)
* [Bootstrapping the Kubernetes Control Plane](docs/04-bootstrapping-kubernetes-controllers.md)
* [Bootstrapping the Kubernetes Worker Nodes](docs/05-bootstrapping-kubernetes-workers.md)
* [Provisioning Pod Network Routes](docs/06-pod-network-routes.md)
* [Deploying the DNS Cluster Add-on](docs/07-dns-addon.md)
* [Smoke Test](docs/08-smoke-test.md)
