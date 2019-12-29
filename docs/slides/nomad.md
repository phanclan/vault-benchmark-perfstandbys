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

- Are very lightweight; interface with the server nodes and maintain very little state of their own.
- Each cluster has usually 3 or 5 server mode agents and potentially thousands of clients.

---
name: running-an-agent
class: compact, col-2

# Running an Agent

The agent is started with the [`nomad agent` command](https://www.nomadproject.io/docs/commands/agent.html).

- This command blocks, running forever or until told to quit.
- The agent command takes a variety of configuration options, but most have sane defaults.

When running nomad agent, you should see output similar to this:

``` shell
$ nomad agent -dev
==> Starting Nomad agent...
==> Nomad agent configuration:

                Client: true
             Log Level: INFO
                Region: global (DC: dc1)
                Server: true

==> Nomad agent started! Log data will stream in below:

    [INFO] serf: EventMemberJoin: server-1.node.global 127.0.0.1
    [INFO] nomad: starting 4 scheduling worker(s) for [service batch _core]
...
```

There are several important messages that nomad agent outputs:

- **Client**: This indicates whether the agent has enabled client mode. Client nodes fingerprint their host environment, register with servers, and run tasks.
- **Log Level**: This indicates the configured log level. Only messages with an equal or higher severity will be logged. This can be tuned to increase verbosity for debugging, or reduced to avoid noisy logging.
- **Region**: This is the region and datacenter in which the agent is configured to run. Nomad has first-class support for multi-datacenter and multi-region configurations. The -region and -dc flags can be used to set the region and datacenter. The default is the global region in dc1.
- **Server**: This indicates whether the agent has enabled server mode. Server nodes have the extra burden of participating in the consensus protocol, storing cluster state, and making scheduling decisions.

---
name: stopping-an-agent
class: compact

# Stopping an Agent

An agent can be stopped in two ways: gracefully or forcefully.

- By default, any signal to an agent (interrupt, terminate, kill) will cause the agent to forcefully stop.
- Graceful termination can be configured by either setting leave_on_interrupt or leave_on_terminate to respond to the respective signals.

When gracefully exiting, clients will update their status to terminal on the servers so that tasks can be migrated to healthy agents.

- Servers will notify their intention to leave the cluster which allows them to leave the [<u>consensus](https://www.nomadproject.io/docs/internals/consensus.html)</u> peer set.

It is especially important that a server node be allowed to leave gracefully so that there will be a minimal impact on availability as the server leaves the consensus peer set.

- If a server does not gracefully leave, and will not return into service, the [<u>server force-leave command](https://www.nomadproject.io/docs/commands/server/force-leave.html  )</u> should be used to eject it from the consensus peer set.

---
name: lifecycle
class: compact

# Lifecycle

Every agent in the Nomad cluster goes through a lifecycle. Understanding this lifecycle is useful for building a mental model of an agent's interactions with a cluster and how the cluster treats a node.

When a client agent is first started, it fingerprints the host machine to identify its attributes, capabilities, and [<u>task drivers][6]</u>. These are reported to the servers during an initial registration. The addresses of known servers are provided to the agent via configuration, potentially using DNS for resolution. Using [<u>Consul][7]</u> provides a way to avoid hard coding addresses and resolving them on demand.

While a client is running, it is performing heartbeating with servers to maintain liveness. If the heartbeats fail, the servers assume the client node has failed, and stop assigning new tasks while migrating existing tasks. It is impossible to distinguish between a network failure and an agent crash, so both cases are handled the same. Once the network recovers or a crashed agent restarts the node status will be updated and normal operation resumed.

To prevent an accumulation of nodes in a terminal state, Nomad does periodic garbage collection of nodes. By default, if a node is in a failed or 'down' state for over 24 hours it will be garbage collected from the system.

Servers are slightly more complex as they perform additional functions. They participate in a [<u>gossip protocol][8]</u> both to cluster within a region and to support multi-region configurations. When a server is first started, it does not know the address of other servers in the cluster. To discover its peers, it must _join_ the cluster. This is done with the [<u>server join command][9]</u> or by providing the proper configuration on start. Once a node joins, this information is gossiped to the entire cluster, meaning all nodes will eventually be aware of each other.

When a server _leaves_, it specifies its intent to do so, and the cluster marks that node as having _left_. If the server has _left_, replication to it will stop and it is removed from the consensus peer set. If the server has _failed_, replication will attempt to make progress to recover from a software or network failure.

---
name: permissions

# [**<u>»**][10]**</u> Permissions**

Nomad servers should be run with the lowest possible permissions. Nomad clients must be run as root due to the OS isolation mechanisms that require root privileges. In all cases, it is recommended you create a nomad user with the minimal set of required privileges.


[6]: https://www.nomadproject.io/docs/drivers/index.html
[7]: https://www.consul.io/
[8]: https://www.nomadproject.io/docs/internals/gossip.html
[9]: https://www.nomadproject.io/docs/commands/server/join.html
[10]: https://www.nomadproject.io/guides/install/production/nomad-agent.html#permissions


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

