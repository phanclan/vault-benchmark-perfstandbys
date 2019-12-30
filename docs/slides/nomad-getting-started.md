class: title, smokescreen, shelf, no-footer
background-image: url(tech-background-01.png)

# Running Nomad

## Peter Phan, pphan@hashicorp.com

---

Nomad relies on a long running agent on every machine in the cluster. The agent can run either in server or client mode. Each region must have at least one server, though a cluster of 3 or 5 servers is recommended. A single server deployment is _highly_ discouraged as data loss is inevitable in a failure scenario.

All other agents run in client mode. A Nomad client is a very lightweight process that registers the host machine, performs heartbeating, and runs the tasks that are assigned to it by the servers. The agent must be run on every node that is part of the cluster so that the servers can assign work to those machines.

---
layout: true

.footer[
- Copyright © 2019 HashiCorp
- [the components](#components)
- ![logo](https://hashicorp.github.io/field-workshops-assets/assets/logos/HashiCorp_Icon_Black.svg)
]

---
name: starting-the-agent
class: compact, col-2

# Starting the Agent

- We will run a single Nomad agent in **development** mode.
  - Starts an agent that acts as a client and server to test job configurations or prototype interactions.
  - Should **_not_** be used in production; does not persist state.

```shell
*$ sudo nomad agent -dev
```

???

```shell
nomad agent -dev > nomad.log 2>&1 &
```

---
class: compact, col-2

- The Nomad agent has started and has output some log data.
  - agent is running in both **client** and **server** mode
  - has claimed leadership of the cluster
  - the local client has been **registered** and marked as **ready**.

```shell
==> Starting Nomad agent...
==> Nomad agent configuration:
*               Client: true
             Log Level: DEBUG
                Region: global (DC: dc1)
*               Server: true
==> Nomad agent started! Log data will stream in below:
    [INFO] serf: EventMemberJoin: nomad.global 127.0.0.1
    [INFO] nomad: starting 4 scheduling worker(s) for [service batch _core]
    [INFO] client: using alloc directory /tmp/NomadClient599911093
    [INFO] raft: Node at 127.0.0.1:4647 [Follower] entering Follower state
    [INFO] nomad: adding server nomad.global (Addr: 127.0.0.1:4647) (DC: dc1)
    [WARN] fingerprint.network: Ethtool not found, checking /sys/net speed file
    [WARN] raft: Heartbeat timeout reached, starting election
    [INFO] raft: Node at 127.0.0.1:4647 [Candidate] entering Candidate state
    [DEBUG] raft: Votes needed: 1
    [DEBUG] raft: Vote granted. Tally: 1
    [INFO] raft: Election won. Tally: 1
*   [INFO] raft: Node at 127.0.0.1:4647 [Leader] entering Leader state
    [INFO] raft: Disabling EnableSingleNode (bootstrap)
    [DEBUG] raft: Node 127.0.0.1:4647 updated peer set (2): [127.0.0.1:4647]
*   [INFO] nomad: cluster leadership acquired
    [DEBUG] client: applied fingerprints [arch cpu host memory storage network]
    [DEBUG] client: available drivers [docker exec java]
*   [DEBUG] client: node registration complete
    [DEBUG] client: updated allocations at index 1 (0 allocs)
    [DEBUG] client: allocs: (added 0) (removed 0) (updated 0) (ignore 0)
*   [DEBUG] client: state updated to ready
```

???

- **Note:** Typically any agent running in client mode must be run with root level privilege.
  - Nomad makes use of operating system primitives for resource isolation which require elevated permissions.
  - The agent will function as non-root, but certain task drivers will not be available.

---
name: cluster-nodes
class: compact

# Cluster Nodes

- Run [`nomad node status`](https://www.nomadproject.io/docs/commands/node/status.html) in another terminal
- You can see the registered nodes of the Nomad cluster:

```shell
*$ nomad node status
ID        DC   Name   Class   Drain  Eligibility  Status
171a583b  dc1  nomad  <none>  false  eligible     ready
```

- The output shows our Node ID, which is a randomly generated UUID, its datacenter, node name, node class, drain mode and current status.
- We can see that our node is in the ready state, and task draining is currently off.

---
class: compact, col-2

- The agent is also running in **server** mode.
  - This means it is part of the [gossip protocol](https://www.nomadproject.io/docs/internals/gossip.html) used to connect all the server instances together.
  - We can view the members of the gossip ring using the [`server members`](https://www.nomadproject.io/docs/commands/server/members.html) command:

```shell
*$ nomad server members
Name          Address    Port  Status  Leader  Protocol  Build  Datacenter  Region
nomad.global  127.0.0.1  4648  alive   true    2         0.9.6  dc1         global
```

- The output shows our own agent, the address it is running on, its health state, some version information, and the datacenter and region.
  - Additional metadata can be viewed by providing the `-detailed` flag.

---
name: stopping-the-agent
class: compact

# Stopping the Agent

- You can use `Ctrl-C` (the interrupt signal) to halt the agent.
  - By default, all signals will cause the agent to forcefully shutdown.
  - The agent [can be configured](https://www.nomadproject.io/docs/configuration/index.html#leave_on_terminate) to gracefully leave on either the **interrupt** or **terminate** signals.
- After interrupting the agent, you should see it leave the cluster and shut down:

```shell
^C==> Caught signal: interrupt
    [DEBUG] http: Shutting down http server
    [INFO] agent: requesting shutdown
    [INFO] client: shutting down
    [INFO] nomad: shutting down server
    [WARN] serf: Shutdown without a Leave
    [INFO] agent: shutdown complete
```

---
class: compact

- By gracefully leaving, 
  - Nomad clients update their status to prevent further tasks from being scheduled and to start migrating any tasks that are already assigned. 
  - Nomad servers notify their peers they intend to leave. 
    - When a server leaves, replication to that server stops. 
    - If a server fails, replication continues to be attempted until the node recovers. 
  - Nomad will automatically try to reconnect to _failed_ nodes, allowing it to recover from certain network conditions, while _left_ nodes are no longer contacted.

---
class: compact

- If an agent is operating as a server, [`leave_on_terminate`](https://www.nomadproject.io/docs/configuration/index.html#leave_on_terminate) should only be set if the server will never rejoin the cluster again. 
  - The default value of false for `leave_on_terminate` and `leave_on_interrupt` work well for most scenarios. 
  - If Nomad servers are part of an auto scaling group where new servers are brought up to replace failed servers, using graceful leave avoids causing a potential availability outage affecting the [consensus protocol](https://www.nomadproject.io/docs/internals/consensus.html). 
  - As of **Nomad 0.8**, Nomad includes **Autopilot** which automatically removes failed or dead servers. 
    - This allows the operator to skip setting `leave_on_terminate`

---
class: compact

- If a server does forcefully exit and will not be returning into service, the [`server force-leave` command](https://www.nomadproject.io/docs/commands/server/force-leave.html) should be used to force the server from a _failed_ to a _left_ state.
- Start the agent again with the `sudo nomad agent -dev` command before continuing to the next section.

```shell
*$ sudo nomad agent -dev > nomad.log 2>&1 &
```












---
class: title, smokescreen, shelf, no-footer
background-image: url(tech-background-01.png)

# Jobs

---

- Jobs are the primary configuration that users interact with when using Nomad. A job is a declarative specification of tasks that Nomad should run. Jobs have a globally unique name, one or many task groups, which are themselves collections of one or many tasks.
- The format of the jobs is documented in the [job specification](https://www.nomadproject.io/docs/job-specification/index.html). They can either be specified in [HashiCorp Configuration Language](https://github.com/hashicorp/hcl) or JSON, however we recommend only using JSON when the configuration is generated by a machine.

---
class: compact, col-2
# Running a Job

- To get started, we will use the [`job init` command](https://www.nomadproject.io/docs/commands/job/init.html) which generates a skeleton job file:

```shell
*$ nomad job init
Example job file written to example.nomad
```

- You can view the contents of this file by running `cat example.nomad`.
  - `grep -vE "^*#|^$" example.nomad`
- In this example job file, we have declared a single task '`redis`' which is using the Docker driver to run the task. 
  - The primary way you interact with Nomad is with the [`job run` command](https://www.nomadproject.io/docs/commands/job/run.html). 
  - The `run` command takes a job file and registers it with Nomad. 
  - This is used both to register new jobs and to update existing jobs.

---
class: compact

- We can register our example job now:

```shell
*$ nomad job run example.nomad
==> Monitoring evaluation "13ebb66d"
    Evaluation triggered by job "example"
    Allocation "883269bf" created: node "e42d6f19", group "cache"
    Evaluation within deployment: "b0a84e74"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "13ebb66d" finished with status "complete"
```

---
class: compact, col-2

- Anytime a job is updated, Nomad creates an evaluation to determine what actions need to take place. 
  - In this case, because this is a new job, Nomad has determined that an allocation should be created and has scheduled it on our local agent.
- To inspect the status of our job we use the [`nomad status` command](https://www.nomadproject.io/docs/commands/status.html):
  - Here we can see that the result of our evaluation was the creation of an allocation that is now running on the local node.
  - Our Node ID can be seen with `nomad node status`

```shell
*$ nomad status example
ID            = example
Name          = example
Submit Date   = 08/31/19 22:58:40 UTC
Type          = service
Priority      = 50
Datacenters   = dc1
Status        = running
Periodic      = false
Parameterized = false

Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost
cache       0       0         1        0       0         0

Latest Deployment
ID          = b0a84e74
*Status      = successful
Description = Deployment completed successfully

Deployed
Task Group  Desired  Placed  Healthy  Unhealthy
cache       1        1       1        0

Allocations
ID        Node ID   Task Group  Version  Desired  Status   Created  Modified
*8ba85cef  171a583b  cache       0        run      running  5m ago   5m ago
```

---
class: compact, col-2

- An allocation represents an instance of **Task Group** placed on a node.
- To inspect an allocation we use the [`nomad alloc status <alloc_id>` command](https://www.nomadproject.io/docs/commands/alloc/status.html):
  - We can see that Nomad reports the state of the allocation as well as its current resource usage.
  - By supplying the `-stats` flag, more detailed resource usage statistics will be reported.

```shell
*$ nomad alloc status 8ba85cef
ID                  = 8ba85cef
Eval ID             = 13ebb66d
Name                = example.cache[0]
Node ID             = e42d6f19
Job ID              = example
Job Version         = 0
Client Status       = running
Client Description  = <none>
Desired Status      = run
Desired Description = <none>
Created             = 5m ago
Modified            = 5m ago
Deployment ID       = fa882a5b
Deployment Health   = healthy

Task "redis" is "running"
Task Resources
CPU        Memory           Disk     IOPS  Addresses
8/500 MHz  6.3 MiB/256 MiB  300 MiB  0     db: 127.0.0.1:22672

Task Events:
Started At     = 08/31/19 22:58:49 UTC
Finished At    = N/A
Total Restarts = 0
Last Restart   = N/A

Recent Events:
Time                   Type        Description
08/31/19 22:58:49 UTC  Started     Task started by client
08/31/19 22:58:40 UTC  Driver      Downloading image redis:3.2
08/31/19 22:58:40 UTC  Task Setup  Building Task Directory
08/31/19 22:58:40 UTC  Received    Task received by client
```

---
class: compact, col-2

- To see the logs of a task, we can use the [`nomad alloc logs <allocation> <task>` command](https://www.nomadproject.io/docs/commands/alloc/logs.html):

```shell
$ nomad alloc logs 8ba85cef redis
                 _._
            _.-``__ ''-._
       _.-``    `.  `_.  ''-._           Redis 3.2.1 (00000000/0) 64 bit
   .-`` .-```.  ```\/    _.,_ ''-._
  (    '      ,       .-`  | `,    )     Running in standalone mode
  |`-._`-...-` __...-.``-._|'` _.-'|     Port: 6379
  |    `-._   `._    /     _.-'    |     PID: 1
   `-._    `-._  `-./  _.-'    _.-'
  |`-._`-._    `-.__.-'    _.-'_.-'|
  |    `-._`-._        _.-'_.-'    |           http://redis.io
   `-._    `-._`-.__.-'_.-'    _.-'
  |`-._`-._    `-.__.-'    _.-'_.-'|
  |    `-._`-._        _.-'_.-'    |
   `-._    `-._`-.__.-'_.-'    _.-'
       `-._    `-.__.-'    _.-'
           `-._        _.-'
               `-.__.-'
...
```

---
class: compact, col-2

# Modifying a Job

- The definition of a job is not static, and is meant to be updated over time. 
- You may update a job 
  - to change the docker container, 
  - to update the application version, or 
  - to change the count of a task group to scale with load.
- For now, edit the `example.nomad` file to update the `count` and set it to `3`. This line is in the `cache` section around line `145`.

```shell
# The "count" parameter specifies the number of the task groups that should
# be running under this group. This value must be non-negative and defaults
# to 1.
count = 3
```

---
class: compact, col-2

- Use the [`nomad job plan` command](https://www.nomadproject.io/docs/commands/job/plan.html) to **invoke a dry-run of the scheduler** to see what would happen if you ran the updated job:
  - Note that the scheduler detected the change in count and informs us that it will cause `2` new instances to be created. 
    - The `in-place update` that will occur is to push the updated job specification to the existing allocation and will not cause any service interruption.

```shell
*$ nomad job plan example.nomad
+/- Job: "example"
*+/- Task Group: "cache" (2 create, 1 in-place update)
* +/- Count: "1" => "3" (forces create)
      Task: "redis"

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 7
To submit the job with version verification run:

*nomad job run -check-index 7 example.nomad

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plan's results are
potentially invalid.
```

---
class: compact, col-2

- Run the job with the `nomad job run` command the `plan` displayed.
  - By running with the `-check-index` flag, Nomad checks that the job has not been modified since the plan was run. 
  - This is useful if multiple people are interacting with the job at the same time to ensure the job hasn't changed before you apply your modifications.
  - Because we set the count of the task group to `three`, Nomad created two additional allocations to get to the desired state. It is **idempotent** to run the same job specification again (`nomad job run`) and no new allocations will be created.

```shell
*$ nomad job run -check-index 7 example.nomad
==> Monitoring evaluation "93d16471"
    Evaluation triggered by job "example"
    Evaluation within deployment: "0d06e1b6"
*   Allocation "3249e320" created: node "e42d6f19", group "cache"
*   Allocation "453b210f" created: node "e42d6f19", group "cache"
    Allocation "883269bf" modified: node "e42d6f19", group "cache"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "93d16471" finished with status "complete"
```

---
class: compact, col-2

- Let's do an application update. 
  - We will change the version of redis we want to run. 
  - Edit the `example.nomad` file and change the Docker image from "`redis:3.2`" to "`redis:4.0`". 
    - This is located around line `261`.

```go
# Configure Docker driver with the image
config {
    image = "redis:4.0"
}
```

---
class: compact, col-2

- We can run `nomad job plan` again to see what will happen if we submit this change:
  - The `plan` output shows us that one allocation will be updated and that the other two will be ignored. 
  - This is due to the `max_parallel` setting in the `update` stanza, which is set to `1` to instruct Nomad to perform only a single change at a time.

```shell
$ nomad job plan example.nomad
+/- Job: "example"
*+/- Task Group: "cache" (1 create/destroy update, 2 ignore)
  +/- Task: "redis" (forces create/destroy update)
    +/- Config {
      +/- image:           "redis:3.2" => "redis:4.0"
          port_map[0][db]: "6379"
        }

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 1127
To submit the job with version verification run:

nomad job run -check-index 1127 example.nomad

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plan's results are
potentially invalid.
```

---
class: compact, col-2

- Once ready, use `nomad job run` to push the updated specification:

```shell
*$ nomad job run example.nomad
==> Monitoring evaluation "293b313a"
    Evaluation triggered by job "example"
    Evaluation within deployment: "f4047b3a"
    Allocation "27bd4a41" created: node "e42d6f19", group "cache"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "293b313a" finished with status "complete"
```

---
class: compact, col-2

- After running, the rolling upgrade can be followed by running `nomad status` and watching the deployed count.
- We can see that Nomad handled the update in three phases, only updating a single allocation in each phase and waiting for it to be healthy for `min_healthy_time` of `10` seconds before moving on to the next. 
- The update strategy can be configured, but rolling updates makes it easy to upgrade an application at large scale.

```shell
*$ nomad status example
ID            = example
...
Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost
cache       0       0         3        0       3         0

Latest Deployment
ID          = 6eb0d89e
Status      = successful
Description = Deployment completed successfully

Deployed
Task Group  Desired  Placed  Healthy  Unhealthy  Progress Deadline
cache       3        3       3        0          2019-12-30T21:05:13Z

Allocations
ID        Node ID   Task Group  Version  Desired  Status    Created     Modified
0a60166b  36f0faa2  cache       2        run      running   54s ago     42s ago
de99d024  36f0faa2  cache       2        run      running   1m9s ago    56s ago
50725887  36f0faa2  cache       2        run      running   1m31s ago   1m10s ago
857be359  36f0faa2  cache       1        stop     complete  10m9s ago   1m8s ago
cec3d753  36f0faa2  cache       1        stop     complete  10m9s ago   54s ago
74e7c86a  36f0faa2  cache       1        stop     complete  47m43s ago  1m31s ago
```

---
class: compact, col-2

# Stopping a Job

- So far we've created, ran and modified a job. 
- The final step in a job lifecycle is stopping the job. 
- This is done with the [`nomad job stop command`](https://www.nomadproject.io/docs/commands/job/stop.html):

```shell
*$ nomad job stop example
==> Monitoring evaluation "6d4cd6ca"
    Evaluation triggered by job "example"
    Evaluation within deployment: "f4047b3a"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "6d4cd6ca" finished with status "complete"
```

---
class: compact, col-2

- When we stop a job, it creates an evaluation which is used to stop all the existing allocations. 
- If we now query the job status, we can see it is now marked as `dead (stopped)`.
  - Indicating that the job has been stopped and Nomad is no longer running it:

```shell
$ nomad status example
ID            = example
Name          = example
Submit Date   = 08/31/19 17:30:40 UTC
Type          = service
Priority      = 50
Datacenters   = dc1
*Status        = dead (stopped)
Periodic      = false
Parameterized = false

Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost
cache       0       0         0        0       6         0

Latest Deployment
ID          = f4047b3a
Status      = successful
Description = Deployment completed successfully

Deployed
Task Group  Desired  Placed  Healthy  Unhealthy
cache       3        3       3        0

Allocations
ID        Node ID   Task Group  Version  Desired  Status    Created    Modified
8ace140d  2cfe061e  cache       2        stop     complete  5m ago     5m ago
8af5330a  2cfe061e  cache       2        stop     complete  6m ago     6m ago
df50c3ae  2cfe061e  cache       2        stop     complete  6m ago     6m ago
```

---
class: compact, col-2

- If we wanted to start the job again, we could simply `run` it again.
- Users of Nomad primarily interact with jobs, and we've now seen how to create and scale our job, perform an application update, and do a job tear down. 
- Next we will add another Nomad client to create our first cluster.
- Stop the Nomad agent with `Ctrl-C` before moving on to the next section.
- Or

```shell
pkill nomad
```











---
class: title, smokescreen, shelf, no-footer
background-image: url(tech-background-01.png)

# Clustering

---

We have started our first agent and run a job against it in development mode. This demonstrates the ease of use and the workflow of Nomad, but did not show how this could be extended to a scalable, production-grade configuration.

In this step, we will create our first real cluster with multiple nodes.

---
class: compact, col-2

# Starting the Server

- The first step is to create the config file for the server. Either download the [file from the repository][1], or paste this into a file called `server.hcl`:
  - This is a minimal server configuration file, but it is enough to start an agent in server only mode and have it elected as a leader. 
  - The major change that should be made for production is to run more than one server, and to change the corresponding `bootstrap_expect` value.

```go
# Increase log verbosity
log_level = "DEBUG"

# Setup data dir
data_dir = "/tmp/server1"

# Enable the server
server {
    enabled = true

    # Self-elect, should be 3 or 5 for production
    bootstrap_expect = 1
}
```

---
class: compact, col-2

- Once the file is created, start the agent in a new tab:
- `nomad agent -config server.hcl`
- Or...

```shell
nomad agent -config server.hcl > /tmp/nomad.log 2>&1 &
```

- Note that **client** mode is disabled, and that we are only running as the server.
- This server will manage state and make scheduling decisions but will not run any tasks.
- Now we need some agents to run tasks!

```shell
==> WARNING: Bootstrap mode enabled! Potentially unsafe operation.
==> Starting Nomad agent...
==> Nomad agent configuration:

*               Client: false
             Log Level: DEBUG
                Region: global (DC: dc1)
*               Server: true
               Version: 0.9.6

==> Nomad agent started! Log data will stream in below:

    [INFO] serf: EventMemberJoin: nomad.global 127.0.0.1
    [INFO] nomad: starting 4 scheduling worker(s) for [service batch _core]
    [INFO] raft: Node at 127.0.0.1:4647 [Follower] entering Follower state
    [INFO] nomad: adding server nomad.global (Addr: 127.0.0.1:4647) (DC: dc1)
    [WARN] raft: Heartbeat timeout reached, starting election
    [INFO] raft: Node at 127.0.0.1:4647 [Candidate] entering Candidate state
    [DEBUG] raft: Votes needed: 1
    [DEBUG] raft: Vote granted. Tally: 1
    [INFO] raft: Election won. Tally: 1
    [INFO] raft: Node at 127.0.0.1:4647 [Leader] entering Leader state
    [INFO] nomad: cluster leadership acquired
    [INFO] raft: Disabling EnableSingleNode (bootstrap)
    [DEBUG] raft: Node 127.0.0.1:4647 updated peer set (2): [127.0.0.1:4647]
```

---
class: compact, col-2

# Starting the Clients

- Similar to the server, we must first configure the clients. 
- Either download the configuration for `client1` and `client2` from the [repository here][2], or paste the following into `client1.hcl`:

```go
# Increase log verbosity
log_level = "DEBUG"

# Setup data dir
data_dir = "/tmp/client1"

# Give the agent a unique name. Defaults to hostname
name = "client1"

# Enable the client
client {
    enabled = true

    # For demo assume we are talking to server1. For production,
    # this should be like "nomad.service.consul:4647" and a system
    # like Consul used for service discovery.
    servers = ["127.0.0.1:4647"]
}

# Modify our port to avoid a collision with server1
ports {
    http = 5656
}
```

---
class: compact, col-2

- Copy the file you just created to create another one similar to it called `client2.hcl`.
  - `cp client1.hcl client2.hcl`
- Change the `data_dir` to be `/tmp/client2`, the name to `client2`, and the `http` port to `5657`.

```shell
sed 's/client1/client2/g;s/5656/5657/g' client1.hcl > client2.hcl
```

- Once you have created both `client1.hcl` and `client2.hcl`, open a tab for each and start the agents (the process for the first agent is shown below but be sure to do the same for the second agent):

```shell
nomad agent -config nomadclient1.hcl > /tmp/nomadclient1.log 2>&1 &
nomad agent -config nomadclient2.hcl > /tmp/nomadclient2.log 2>&1 &
```

```shell
$ sudo nomad agent -config client1.hcl
==> Starting Nomad agent...
==> Nomad agent configuration:

                Client: true
             Log Level: DEBUG
                Region: global (DC: dc1)
                Server: false
               Version: 0.9.6

==> Nomad agent started! Log data will stream in below:

    [DEBUG] client: applied fingerprints [host memory storage arch cpu]
    [DEBUG] client: available drivers [docker exec]
    [DEBUG] client: node registration complete
    ...
```

---
class: compact, col-2

- In the output we can see the agent is running in **_client_** mode only. This agent will be available to run tasks but will not participate in managing the cluster or making scheduling decisions.
- Using the [`nomad node status` command][3] we should see both nodes in the ready state:
- We now have a simple three node cluster running. 
  - The only difference between a demo and full production cluster is that we are running a single server instead of three or five.

```shell
$ nomad node status
ID        DC   Name     Class   Drain  Eligibility  Status
fca62612  dc1  client1  <none>  false  eligible     ready
c887deef  dc1  client2  <none>  false  eligible     ready
```

# Submit a Job**

- Now that we have a simple cluster, we can use it to schedule a job. We should still have the `example.nomad` job file from before, but verify that the count is still set to 3.
- Then, use the [job run command][4] to submit the job:
    - ```
        $ nomad job run example.nomad
        ==> Monitoring evaluation "8e0a7cf9"
            Evaluation triggered by job "example"
            Evaluation within deployment: "0917b771"
            Allocation "501154ac" created: node "c887deef", group "cache"
            Allocation "7e2b3900" created: node "fca62612", group "cache"
            Allocation "9c66fcaf" created: node "c887deef", group "cache"
            Evaluation status changed: "pending" -> "complete"
        ==> Evaluation "8e0a7cf9" finished with status "complete"
- We can see in the output that the scheduler assigned two of the tasks for one of the client nodes and the remaining task to the second client.
- We can again use the [`status command`][5] to verify:
    - ```
        $ nomad status example
        ID          = example
        Name        = example
        Submit Date   = 07/26/19 16:34:58 UTC
        Type        = service
        Priority    = 50
        Datacenters = dc1
        Status      = running
        Periodic    = false
        Parameterized = false

        Summary
        Task Group  Queued  Starting  Running  Failed  Complete  Lost
        cache       0       0         3        0       0         0

        Latest Deployment
        ID          = fc49bd6c
        Status      = running
        Description = Deployment is running

        Deployed
        Task Group  Desired  Placed  Healthy  Unhealthy
        cache       3        3       0        0

        Allocations
        ID        Eval ID   Node ID   Task Group  Desired  Status   Created At
        501154ac  8e0a7cf9  c887deef  cache       run      running  08/08/19 21:03:19 <--- client2
        7e2b3900  8e0a7cf9  fca62612  cache       run      running  08/08/19 21:03:19 <--- client1
        9c66fcaf  8e0a7cf9  c887deef  cache       run      running  08/08/19 21:03:19 <--- client2
- We can see that all our tasks have been allocated and are running. Once we are satisfied that our job is happily running, we can tear it down with `nomad job stop`.
- Nomad is now up and running. The cluster can be entirely managed from the command line, but Nomad also comes with a web interface that is hosted alongside the HTTP API. Next, we'll visit the UI in the browser.
- Re-run the example job if you stopped it previously before heading to the next section.

[1]: https://raw.githubusercontent.com/hashicorp/nomad/master/demo/vagrant/server.hcl
[2]: https://github.com/hashicorp/nomad/tree/master/demo/vagrant
[3]: https://www.nomadproject.io/docs/commands/node/status.html
[4]: https://www.nomadproject.io/docs/commands/job/run.html
[5]: https://www.nomadproject.io/docs/commands/status.html







---
class: compact, col-2

# Common Nomad Commands

