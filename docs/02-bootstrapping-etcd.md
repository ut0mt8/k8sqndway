# Bootstrapping the etcd Cluster

Kubernetes components are stateless and store cluster state in [etcd](https://github.com/coreos/etcd). In this section you will bootstrap a three nodes etcd cluster and configure it for high availability and *unsecure* remote access.

## Prerequisites

The commands in this section must be run on each controller node: `ctrl00`, `ctrl01`, and `ctrl02`. Login to each controller node using ssh.

## Bootstrapping an etcd Cluster Member

### Download and Install the etcd Binaries

Download the official etcd release binaries from the [coreos/etcd](https://github.com/coreos/etcd) GitHub project:

```
wget "https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz"
```

Extract and install the `etcd` server and the `etcdctl` command line utility:

```
tar -xvf etcd-v3.3.9-linux-amd64.tar.gz
```

```
sudo mv etcd-v3.3.9-linux-amd64/etcd* /usr/local/bin/
```

### Configure the etcd Server

```
sudo mkdir -p /etc/etcd /var/lib/etcd
```

Each etcd member must have a unique name within an etcd cluster. Set the etcd name to match the hostname and private internal ip of the current node:

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
  --initial-cluster ctrl00=http://10.42.0.1:2380,ctrl01=http://10.42.0.2:2380,ctrl02=http://10.42.0.3:2380 \\
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

> Remember to run the above commands on each controller vm: `ctrl00`, `ctrl01`, and `ctrl02`.

## Verification

List the etcd cluster members (on any controller node):

```
ETCDCTL_API=3 etcdctl member list
```

> output

```
885d39f23735e385, started, ctrl01, http://10.42.0.2:2380, http://10.42.0.2:2379
9c41b374fd2f0a23, started, ctrl00, http://10.42.0.1:2380, http://10.42.0.1:2379
c3714509dde986c4, started, ctrl02, http://10.42.0.3:2380, http://10.42.0.3:2379
```

