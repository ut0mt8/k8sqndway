# Provisioning Pod Network Routes

Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network.

In this section you will create a route for each worker node that maps the node's Pod CIDR range to the node's internal IP address, aka static networking mode.

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

> You should make these persistent, the method depend on your distribution.

