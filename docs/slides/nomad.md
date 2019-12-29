class: title, smokescreen, shelf, no-footer
background-image: url(tech-background-01.png)

# Installing Nomad

## Peter Phan, pphan@hashicorp.com

---
layout: true

.footer[
- Copyright © 2019 HashiCorp
- [the components](#components)
- ![logo](https://hashicorp.github.io/field-workshops-assets/assets/logos/HashiCorp_Icon_Black.svg)
]

---
class: img-right-full

![start](images/jukan-tateisi-bJhT_8nbUA0-unsplash.jpg)

# Getting Started

- [<u>Reference Material ][1]</u>
- [<u>Estimated Time to Complete][2]</u>
- [<u>Challenge][3]</u>
- [<u>Solution][4]</u>
- [<u>Prerequisites][5]</u>
- [<u>Steps][6]</u>
- [<u>Next Steps][7]</u>

This guide explains how to configure [<u>Prometheus][8]</u> to integrate with a Nomad cluster and Prometheus [<u>Alertmanager][9]</u>. 

???
While this guide introduces the basics of enabling [<u>telemetry][10]</u> and alerting, a Nomad operator can go much further by customizing dashboards and integrating different [<u>receivers][11]</u> for alerts.

---
name: reference-material
# Reference Material

- [<u>Configuring Prometheus][13]</u>
- [<u>Telemetry Stanza in Nomad Agent Configuration][14]</u>
- [<u>Alerting Overview][15]</u>
- [_Using Prometheus to Monitor Nomad Metrics_](https://www.nomadproject.io/guides/operations/monitoring-and-alerting/prometheus-metrics.html)

---
name: set-server-and-client-nodes
class: title
background-image: url(tech-background-01.png)

# Set Server & Client Nodes

---
name: setting-nodes
class: col-2

# Setting Nodes with Nomad Agent

The Nomad agent is a long running process

- Runs on every machine that is part of the Nomad cluster.
- Behavior of the agent depends on if it is running in client or server mode.
- Clients are responsible for running tasks, while servers are responsible for managing the cluster.

**Client** mode agents are relatively simple.

- Make use of fingerprinting to determine the capabilities and resources of the host machine, as well as determining what drivers are available. - Clients register with servers to provide the node information, heartbeat to provide liveness, and run any tasks assigned to them.

**Servers** take on the responsibility of being part of the consensus protocol and gossip protocol.

- The consensus protocol, powered by Raft, allows the servers to perform leader election and state replication.
- The gossip protocol allows for simple clustering of servers and multi-region federation.
- The higher burden on the server nodes means that usually they should be run on dedicated instances -- they are more resource intensive than a client node.

**Client nodes** make up the majority of the cluster

- Are very lightweight as they interface with the server nodes and maintain very little state of their own. 
- Each cluster has usually 3 or 5 server mode agents and potentially thousands of clients.

---
name: solution

# Solution

Deploy Prometheus with a configuration that accounts for a highly dynamic environment.

- Integrate service discovery into the configuration file to avoid using hard-coded IP addresses.
- Place the Prometheus deployment behind [<u>fabio][20]</u> (this will allow easy access to the Prometheus web interface by allowing the Nomad operator to hit any of the client nodes at the / path.

---

# Prerequisites

To perform the tasks described in this guide, you need to have a Nomad environment with Consul installed.

- You can use this [<u>repo][22]</u> to easily provision a sandbox environment.
- This guide will assume a cluster with one server node and three client nodes.

**Please Note:** This guide is for demo purposes and is only using a single server node.

- In a production cluster, 3 or 5 server nodes are recommended.
- The alerting rules defined in this guide are for instructional purposes.
- Please refer to [<u>Alerting Rules][23]</u> for more information.

---
name: steps
class: title
background-image: url(tech-background-01.png)

# Steps

---
class: compact, col-2
# Step 1: Enable Telemetry on Nomad Servers and Clients 

Add the stanza below in your Nomad client and server configuration files.

- If you have used the provided repo in this guide to set up a Nomad cluster, the configuration file will be `/etc/nomad.d/nomad.hcl`.

``` go
telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
```

- After making this change, restart the Nomad service on each server and client node.

---
class:compact, col-2

# Step 2: Create a Job for Fabio

Create a job for Fabio and name it `fabio.nomad`

- Note that the `type` option is set to [<u>`system`][28]</u> so that fabio will be deployed on all client nodes. 
- We have also set `network_mode` to `host` so that fabio will be able to use Consul for service discovery.

```go
job "fabio" {
  datacenters = ["dc1"]
*  type = "system"

  group "fabio" {
    task "fabio" {
      driver = "docker"
      config {
        image = "fabiolb/fabio"
        network_mode = "host"
      }

      resources {
        cpu    = 100
        memory = 64
        network {
          mbits = 20
          port "lb" {
            static = 9999
          }
          port "ui" {
            static = 9998
          }
        }
      }
    }
  }
}
```

???
To learn more about fabio and the options used in this job file, see [<u>Load Balancing with Fabio][27]</u>.

---
class:compact, col-2

# Step 3: Run the Fabio Job

Register our fabio job:

```shell
*$ nomad job run fabio.nomad
==> Monitoring evaluation "7b96701e"
    Evaluation triggered by job "fabio"
    Allocation "d0e34682" created: node "28d7f859", group "fabio"
    Allocation "238ec0f7" created: node "510898b6", group "fabio"
    Allocation "9a2e8359" created: node "f3739267", group "fabio"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "7b96701e" finished with status "complete"
```

You should be able to visit any one of your client nodes at port `9998` and see the web interface for fabio.

- The routing table will be empty since we have not yet deployed anything that fabio can route to.
- Accordingly, if you visit any of the client nodes at port `9999` at this point, you will get a `404` HTTP response.
- That will change soon.

---
class:compact, col-2

