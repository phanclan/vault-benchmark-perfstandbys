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
*$ nomad agent -dev
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

---

There are several important messages that nomad agent outputs:

- **Client**: This indicates whether the agent has enabled client mode. Client nodes fingerprint their host environment, register with servers, and run tasks.
- **Log Level**: This indicates the configured log level. Only messages with an equal or higher severity will be logged. This can be tuned to increase verbosity for debugging, or reduced to avoid noisy logging.
- **Region**: This is the region and datacenter in which the agent is configured to run. Nomad has first-class support for multi-datacenter and multi-region configurations. The -region and -dc flags can be used to set the region and datacenter. The default is the global region in dc1.
- **Server**: This indicates whether the agent has enabled server mode. Server nodes have the extra burden of participating in the consensus protocol, storing cluster state, and making scheduling decisions.

---
name: stopping-an-agent
class: compact

# Stopping an Agent

An agent can be stopped in two ways: **gracefully** or **forcefully**.

- By default, any signal to an agent (interrupt, terminate, kill) will cause the agent to forcefully stop.
- Graceful termination can be configured by either setting `leave_on_interrupt` or `leave_on_terminate` to respond to the respective signals.

When gracefully exiting, clients will update their status to terminal on the servers so that tasks can be migrated to healthy agents.

- Servers will notify their intention to leave the cluster which allows them to leave the [<u>consensus](https://www.nomadproject.io/docs/internals/consensus.html)</u> peer set.

It is especially important that a server node be allowed to leave gracefully so that there will be a minimal impact on availability as the server leaves the consensus peer set.

- If a server does not gracefully leave, and will not return into service, the [`server force-leave`](https://www.nomadproject.io/docs/commands/server/force-leave.html) command should be used to eject it from the consensus peer set.

---
name: lifecycle
class: compact

# Lifecycle

Every agent in the Nomad cluster goes through a lifecycle. Understanding this lifecycle is useful for building a mental model of an agent's interactions with a cluster and how the cluster treats a node.

When a client agent is first started, it fingerprints the host machine to identify its attributes, capabilities, and [task drivers][6].

- These are reported to the servers during an initial registration.
- The addresses of known servers are provided to the agent via configuration, potentially using DNS for resolution.
- Using [Consul][7] provides a way to avoid hard coding addresses and resolving them on demand.

---
class: compact

While a client is running, it is performing heartbeating with servers to maintain liveness. If the heartbeats fail, the servers assume the client node has failed, and stop assigning new tasks while migrating existing tasks. It is impossible to distinguish between a network failure and an agent crash, so both cases are handled the same. Once the network recovers or a crashed agent restarts the node status will be updated and normal operation resumed.

---
class: compact

To prevent an accumulation of nodes in a terminal state, Nomad does periodic garbage collection of nodes. By default, if a node is in a failed or 'down' state for over 24 hours it will be garbage collected from the system.

Servers are slightly more complex as they perform additional functions. They participate in a [gossip protocol][8] both to cluster within a region and to support multi-region configurations. When a server is first started, it does not know the address of other servers in the cluster. To discover its peers, it must _join_ the cluster. This is done with the [`server join`][9] command or by providing the proper configuration on start. Once a node joins, this information is gossiped to the entire cluster, meaning all nodes will eventually be aware of each other.

When a server _leaves_, it specifies its intent to do so, and the cluster marks that node as having _left_. If the server has _left_, replication to it will stop and it is removed from the consensus peer set. If the server has _failed_, replication will attempt to make progress to recover from a software or network failure.

---
name: permissions

# Permissions

Nomad servers should be run with the lowest possible permissions.

- Nomad clients must be run as root due to the OS isolation mechanisms that require root privileges.
- In all cases, it is recommended you create a nomad user with the minimal set of required privileges.

[6]: https://www.nomadproject.io/docs/drivers/index.html
[7]: https://www.consul.io/
[8]: https://www.nomadproject.io/docs/internals/gossip.html
[9]: https://www.nomadproject.io/docs/commands/server/join.html

---
class: title, smokescreen, shelf, no-footer
background-image: url(tech-background-01.png)

# Reference Architecture

## Peter Phan, pphan@hashicorp.com

---
class: compact

# Nomad Reference Architecture

This document provides recommended practices and a reference architecture for HashiCorp Nomad production deployments. This reference architecture conveys a general architecture that should be adapted to accommodate the specific needs of each implementation.

The following topics are addressed:

- [Reference Architecture][1]
- [Deployment Topology within a Single Region][2]
- [Deployment Topology across Multiple Regions][3]
- [Network Connectivity Details][4]
- [Deployment System Requirements][5]
- [High Availability][6]
- [Failure Scenarios][7]

This document describes deploying a Nomad cluster in combination with, or with access to, a [Consul cluster][8]. We recommend the use of Consul with Nomad to provide automatic clustering, service discovery, health checking and dynamic configuration.

---
name: reference-architecture
class: compact

# Reference Architecture

A Nomad cluster typically comprises three or five servers (but no more than seven) and a number of client agents.

- Nomad differs slightly from Consul in that it divides infrastructure into regions which are served by one Nomad server cluster, but can manage multiple datacenters or availability zones. 
- For example, a _US Region_ can include datacenters _us-east-1_ and _us-west-2_.

In a Nomad multi-region architecture, communication happens via [WAN gossip][10].

- Additionally, Nomad can integrate easily with Consul to provide features such as automatic clustering, service discovery, and dynamic configurations.
- Thus we recommend you use Consul in your Nomad deployment to simplify the deployment.

In cloud environments, a single cluster may be deployed across multiple availability zones.

- For example, in AWS each Nomad server can be deployed to an associated EC2 instance, and those EC2 instances distributed across multiple AZs.
- Similarly, Nomad server clusters can be deployed to multiple cloud regions to allow for region level HA scenarios.

---

For more information on Nomad server cluster design, see the [cluster requirements documentation][11].

The design shared in this document is the recommended architecture for production environments, as it provides flexibility and resilience. Nomad utilizes an existing Consul server cluster; however, the deployment design of the Consul server cluster is outside the scope of this document.

Nomad to Consul connectivity is over HTTP and should be secured with TLS as well as a Consul token to provide encryption of all traffic. This is done using Nomad's [Automatic Clustering with Consul][12].

---
name: deployment-topology-within-a-single-region

# Deployment Topology within a Single Region

A single Nomad cluster is recommended for applications deployed in the same region.

Each cluster is expected to have either three or five servers. This strikes a balance between availability in the case of failure and performance, as [Raft][14] consensus gets progressively slower as more servers are added.

The time taken by a new server to join an existing large cluster may increase as the size of the cluster increases.

---
class: compact
## Reference Diagram

![](https://www.nomadproject.io/assets/images/nomad_reference_diagram-72c969e0.png)

---
name: deployment-topology-across-multiple-regions
class: compact

# Deployment Topology across Multiple Regions**

By deploying Nomad server clusters in multiple regions, the user is able to interact with the Nomad servers by targeting any region from any Nomad server even if that server resides in a separate region.
- However, most data is not replicated between regions as they are fully independent clusters.
- The exceptions are [ACL tokens and policies][17], as well as [Sentinel policies in Nomad Enterprise][18], which _are_ replicated between regions.

Nomad server clusters in different datacenters can be federated using WAN links.
- The server clusters can be joined to communicate over the WAN on port 4648.
- This same port is used for single datacenter deployments over LAN as well.

Additional documentation is available to learn more about [Nomad server federation][19].

[**»**][20]** Network Connectivity Details**

…

Nomad servers are expected to be able to communicate in high bandwidth, low latency network environments and have below 10 millisecond latencies between cluster members. Nomad servers can be spread across cloud regions or datacenters if they satisfy these latency requirements.

Nomad client clusters require the ability to receive traffic as noted above in the Network Connectivity Details; however, clients can be separated into any type of infrastructure (multi-cloud, on-prem, virtual, bare metal, etc.) as long as they are reachable and can receive job requests from the Nomad servers.

Additional documentation is available to learn more about [Nomad networking][21].

[**»**][22]** Deployment System Requirements**

Nomad server agents are responsible for maintaining the cluster state, responding to RPC queries (read operations), and for processing all write operations. Given that Nomad server agents do most of the heavy lifting, server sizing is critical for the overall performance efficiency and health of the Nomad cluster.

[**»**][23]** Nomad Servers**

**Size**

**CPU**

**Memory**

**Disk**

**Typical Cloud Instance Types**

Small

2 core

8-16 GB RAM

50 GB

**AWS:** m5.large, m5.xlarge

**Azure:** Standard_D2_v3, Standard_D4_v3

**GCE:** n1-standard-8, n1-standard-16

Large

4-8 core

32-64 GB RAM

100 GB

**AWS:** m5.2xlarge, m5.2xlarge

**Azure:** Standard_D4_v3, Standard_D8_v3

**GCE:** n1-standard-16, n1-standard-32

[**»**][24]** Hardware Sizing Considerations**

- The small size would be appropriate for most initial production deployments, or for development/testing environments.
- The large size is for production environments where there is a consistently high workload.

**NOTE** For large workloads, ensure that the disks support a high number of IOPS to keep up with the rapid Raft log update rate.

Nomad clients can be setup with specialized workloads as well. For example, if workloads require GPU processing, a Nomad datacenter can be created to serve those GPU specific jobs and joined to a Nomad server cluster. For more information on specialized workloads, see the documentation on [job constraints][25] to target specific client nodes.

[**»**][26]** High Availability**

A Nomad server cluster is the highly-available unit of deployment within a single datacenter. A recommended approach is to deploy a three or five node Nomad server cluster. With this configuration, during a Nomad server outage, failover is handled immediately without human intervention.

When setting up high availability across regions, multiple Nomad server clusters are deployed and connected via WAN gossip. Nomad clusters in regions are fully independent from each other and do not share jobs, clients, or state. Data residing in a single region-specific cluster is not replicated to other clusters in other regions.

[**»**][27]** Failure Scenarios**

Typical distribution in a cloud environment is to spread Nomad server nodes into separate Availability Zones (AZs) within a high bandwidth, low latency network, such as an AWS Region. The diagram below shows Nomad servers deployed in multiple AZs promoting a single voting member per AZ and providing both AZ-level and node-level failure protection.

…

Additional documentation is available to learn more about [cluster sizing and failure tolerances][28] as well as [outage recovery][29].

[**»**][30]** Availability Zone Failure**

In the event of a single AZ failure, only a single Nomad server will be affected which would not impact job scheduling as long as there is still a Raft quorum (i.e. 2 available servers in a 3 server cluster, 3 available servers in a 5 server cluster, etc.). There are two scenarios that could occur should an AZ fail in a multiple AZ setup: leader loss or follower loss.

[**»**][31]** Leader Server Loss**

If the AZ containing the Nomad leader server fails, the remaining quorum members would elect a new leader. The new leader then begins to accept new log entries and replicates these entries to the remaining followers.

[**»**][32]** Follower Server Loss**

If the AZ containing a Nomad follower server fails, there is no immediate impact to the Nomad leader server or cluster operations. However, there still must be a Raft quorum in order to properly manage a future failure of the Nomad leader server.

[**»**][33]** Region Failure**

In the event of a region-level failure (which would contain an entire Nomad server cluster), clients will still be able to submit jobs to another region that is properly federated. However, there will likely be data loss as Nomad server clusters do not replicate their data to other region clusters. See [Multi-region Federation][34] for more setup information.

[**»**][35]


[1]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#ra
[2]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#one-region
[3]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#multi-region
[4]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#net
[5]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#system-reqs
[6]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#high-availability
[7]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#failure-scenarios
[8]: https://www.nomadproject.io/guides/integrations/consul-integration/index.html
[9]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#reference-architecture
[10]: https://www.nomadproject.io/docs/internals/gossip.html
[11]: https://www.nomadproject.io/guides/install/production/requirements.html
[12]: https://www.nomadproject.io/guides/operations/cluster/automatic.html
[13]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#deployment-topology-within-a-single-region
[14]: https://raft.github.io/
[15]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#reference-diagram
[16]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#deployment-topology-across-multiple-regions
[17]: https://www.nomadproject.io/guides/security/acl.html
[18]: https://www.nomadproject.io/guides/governance-and-policy/sentinel/sentinel-policy.html
[19]: https://www.nomadproject.io/guides/operations/federation.html
[20]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#network-connectivity-details
[21]: https://www.nomadproject.io/guides/install/production/requirements.html#network-topology
[22]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#deployment-system-requirements
[23]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#nomad-servers
[24]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#hardware-sizing-considerations
[25]: https://www.nomadproject.io/docs/job-specification/constraint.html
[26]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#high-availability
[27]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#failure-scenarios
[28]: https://www.nomadproject.io/docs/internals/consensus.html#deployment-table
[29]: https://www.nomadproject.io/guides/operations/outage.html
[30]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#availability-zone-failure
[31]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#leader-server-loss
[32]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#follower-server-loss
[33]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#region-failure
[34]: https://www.nomadproject.io/guides/operations/federation.html
[35]: https://www.nomadproject.io/guides/install/production/reference-architecture.html#next-steps
