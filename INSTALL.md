# Quick Start

## Topology

| Name  | Host IP | Services |
| :-- | :-- | :-------------- |
| Node1 | 192.168.0.1 | PD1, TiKV1, TiDB |
| Node2 | 192.168.0.2 | PD2, TiKV2 |
| Node3 | 192.168.0.3 | PD3, TiKV3 |

## Install

#### RHEL/CentOS/Fedora

```bash
curl 'https://repo.pingcap.org/yum/TiDB.repo' -o /etc/yum.repos.d/TiDB.repo;
yum install -y tidb;
```

#### Debian/Ubuntu

    TODO

## Prepare

#### Stop firewalld

```bash
systemctl stop firewalld
```

## Setup PD Cluster

#### Config

Edit */etc/pd/config.toml* on **Node1**, **Node2**, **Node3**:

```toml
name = "pd1"  # pd2 for Node2, pd3 for Node3
data-dir = "/var/lib/pd"

peer-urls = "http://192.168.0.1:2380"  # 0.2 for Node2, 0.3 for Node3
initial-cluster = "pd1=http://192.168.0.1:2380,pd2=http://192.168.0.2:2380,pd3=http://192.168.0.3:2380"

[log.file]
filename = "/var/log/pd/pd.log"
```

#### Start

On **Node1**, **Node2**, **Node3**:

```bash
systemctl start pd-server
```

## Setup TiKV

#### Config

Edit  */etc/tikv/config.toml* on **Node1**, **Node2**, **Node3**:

```toml
log-file = "/var/log/tikv/tikv.log"

# Use 192.168.0.2 for Node2, 192.168.0.3 for Node3
[server]
addr = "192.168.0.1:20160"
status-addr = "192.168.0.1:20180"

[storage]
data-dir = "/var/lib/tikv"

[pd]
endpoints = ["192.168.0.1:2379", "192.168.0.2:2379", "192.168.0.3:2379"]

```

#### Start

On **Node1**, **Node2**, **Node3**:

```bash
systemctl start tikv-server
```

## Setup TiDB

#### Config

Edit /etc/tidb/config.toml on **Node1**

```toml
store = "tikv"
path = "192.168.0.1:2379,192.168.0.2:2379,192.168.0.3:2379"

[log]
slow-query-file = "/var/log/tidb/tidb-slow.log"

[log.file]
filename = "/var/log/tidb/tidb.log"
```

#### Start

On **Node1**:

```bash
systemctl start tidb-server
```

## Test

```bash
mysql -h 192.168.0.1 -u root -P 4000 -D test
```
