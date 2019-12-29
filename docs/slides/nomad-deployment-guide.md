class: title, smokescreen, shelf, no-footer
background-image: url(tech-background-01.png)

# Nomad Reference Install Guide

## Peter Phan, pphan@hashicorp.com

---
layout: true

.footer[
- Copyright © 2019 HashiCorp
- [the components](#components)
- ![logo](https://hashicorp.github.io/field-workshops-assets/assets/logos/HashiCorp_Icon_Black.svg)
]

---

This deployment guide covers the steps required to install and configure a single HashiCorp Nomad cluster as defined in the [Nomad Reference Architecture][1].

These instructions are for installing and configuring Nomad on Linux hosts running the systemd system and service manager.

---

# [2] Reference Material

This deployment guide is designed to work in combination with the [Nomad Reference Architecture][3] and [Consul Deployment Guide][4]. Although it is not a strict requirement to follow the Nomad Reference Architecture, please ensure you are familiar with the overall architecture design. For example, installing Nomad server agents on multiple physical or virtual (with correct anti-affinity) hosts for high-availability.

---
class: compact

# [5] Overview

To provide a highly-available single cluster architecture, we recommend Nomad server agents be deployed to more than one host, as shown in the [Nomad Reference Architecture][6].

![](https://www.nomadproject.io/assets/images/nomad_reference_diagram-72c969e0.png)

These setup steps should be completed on all Nomad hosts:

- [Download Nomad][7]
- [Install Nomad][8]
- [Configure systemd][9]
- [Configure Nomad][10]
- [Start Nomad][11]

---
class: compact
# [12] Download Nomad

Precompiled Nomad binaries are available for download at [https://releases.hashicorp.com/nomad/][13] and Nomad Enterprise binaries are available for download by following the instructions made available to HashiCorp Enterprise customers.

``` shell
export NOMAD_VERSION="0.9.0"
curl --silent --remote-name https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip
```

You may perform checksum verification of the zip packages using the SHA256SUMS and SHA256SUMS.sig files available for the specific release version. HashiCorp provides [a guide on checksum verification][14] for precompiled binaries.

---
class: compact

# [15]** Install Nomad**

Unzip the downloaded package and move the nomad binary to /usr/local/bin/. Check nomad is available on the system path.

``` shell
unzip nomad_${NOMAD_VERSION}_linux_amd64.zip
sudo chown root:root nomad
sudo mv nomad /usr/local/bin/
nomad version

The nomad command features opt-in autocompletion for flags, subcommands, and arguments (where supported). Enable autocompletion.

``` shell
nomad -autocomplete-install
complete -C /usr/local/bin/nomad nomad
```

Create a data directory for Nomad.
``` shell
sudo mkdir --parents /opt/nomad
```

---
class: compact, col-2

# [16] Configure systemd

Systemd uses [documented sane defaults][17] so only non-default values must be set in the configuration file.

Create a Nomad service file at /etc/systemd/system/nomad.service.

```shell
sudo touch /etc/systemd/system/nomad.service
```

Add this configuration to the Nomad service file:
```yaml
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
Wants=network-online.target
After=network-online.target
[Service]
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad.d
KillMode=process
KillSignal=SIGINT
LimitNOFILE=infinity
LimitNPROC=infinity
Restart=on-failure
RestartSec=2
StartLimitBurst=3
StartLimitIntervalSec=10
TasksMax=infinity
[Install]
WantedBy=multi-user.target
```

---
class: compact, col-3

- The following parameters are set for the `[Unit]` stanza:
  - [`Description`][18] - Free-form string describing the nomad service
  - [`Documentation`][19] - Link to the nomad documentation
  - [`Wants`][20] - Configure a dependency on the network service
  - [`After`][21] - Configure an ordering dependency on the network service being started before the nomad service

- The following parameters are set for the `[Service]` stanza:
  - [`ExecReload`][22] - Send Nomad a SIGHUP signal to trigger a configuration reload
  - [`ExecStart`][23] - Start Nomad with the agent argument and path to a directory of configuration files
  - [`KillMode`][24] - Treat nomad as a single process
  - [`LimitNOFILE`, `LimitNPROC`][25] - Disable limits for file descriptors and processes
  - [`RestartSec`][26] - Restart nomad after 2 seconds of it being considered 'failed'
  - [`Restart`][27] - Restart nomad unless it returned a clean exit code
  - [`StartLimitBurst`, `StartLimitIntervalSec`][28] - Configure unit start rate limiting
  - [`TasksMax`][29] - Disable task limits (only available in systemd >= 226)

- The following parameters are set for the `[Install]` stanza:
  - [`WantedBy`][30] - Creates a weak dependency on nomad being started by the multi-user run level

---
class: compact

# [ 31]** Configure Nomad**

Nomad uses [documented sane defaults][32] so only non-default values must be set in the configuration file. Configuration can be read from multiple files and is loaded in lexical order. See the [full description][33] for more information about configuration loading and merge semantics.

Some configuration settings are common to both server and client Nomad agents, while some configuration settings must only exist on one or the other. Follow the [common configuration][34] guidance on all hosts and then the specific guidance depending on whether you are configuring a Nomad [server][35] or [client][36].

- [Common Nomad configuration][37]
- [Configure a Nomad server][38]
- [Configure a Nomad client][39]

---
name: common-configuration
class: compact, col-2

# Common configuration

Create a configuration file at `/etc/nomad.d/nomad.hcl`:

```shell
sudo mkdir --parents /etc/nomad.d
sudo chmod 700 /etc/nomad.d
sudo touch /etc/nomad.d/nomad.hcl
```

Add this configuration to the `nomad.hcl` configuration file:

- **Note:** Replace the `datacenter` parameter value with the identifier you will use for the datacenter this Nomad cluster is deployed in.

```go
datacenter = "dc1"
data_dir = "/opt/nomad"
```

- [`datacenter`][41] - The datacenter in which the agent is running.
- [`data_dir`][42] - The data directory for the agent to store state.

---
name: server-configuration
class: compact, col-2

# Server configuration

Create a configuration file at `/etc/nomad.d/server.hcl`:

```shell
sudo touch /etc/nomad.d/server.hcl
```

Add this configuration to the `server.hcl` configuration file:

- **NOTE** Replace the `bootstrap_expect` value with the number of Nomad servers you will use; three or five [is recommended][44].

```go
server {
  enabled = true
  bootstrap_expect = 3
}
```

- [`server`][45] - Specifies if this agent should run in server mode. All other server options depend on this value being set.
- [`bootstrap_expect`][46] - The number of expected servers in the cluster. Either this value should not be provided or the value must agree with other servers in the cluster.

---
name: client-configuration
class: compact

# Client configuration

Create a configuration file at `/etc/nomad.d/client.hcl`:

```shell
sudo touch /etc/nomad.d/client.hcl
```

Add this configuration to the `client.hcl` configuration file:

```go
client {
  enabled = true
}
```

- [`client`][48] - Specifies if this agent should run in client mode. All other client options depend on this value being set.
- **NOTE** The [options][49] parameter can be used to enable or disable specific configurations on Nomad clients, unique to your use case requirements.

---
name: acl-configuration

# ACL configuration

The [Access Control][51] guide provides instructions on configuring and enabling ACLs.

---
# [52]** TLS configuration**

Securing Nomad's cluster communication with mutual TLS (mTLS) is recommended for production deployments and can even ease operations by preventing mistakes and misconfigurations. Nomad clients and servers should not be publicly accessible without mTLS enabled.

The [Securing Nomad with TLS][53] guide provides instructions on configuring and enabling TLS.

---
class: compact

# [54]** Start Nomad**

Enable and start Nomad using the systemctl command responsible for controlling systemd managed services. Check the status of the nomad service using systemctl.

```shell
sudo systemctl enable nomad
sudo systemctl start nomad
sudo systemctl status nomad
```

# [55]** Next Steps**

- Read [Outage Recovery][56] to learn the steps required to recover from a Nomad cluster outage.
- Read [Autopilot][57] to learn about features in Nomad 0.8 to allow for automatic operator-friendly management of Nomad servers.

[1]: https://www.nomadproject.io/guides/install/production/reference-architecture.html
[2]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#reference-material
[3]: https://www.nomadproject.io/guides/install/production/reference-architecture.html
[4]: https://www.consul.io/docs/guides/deployment-guide.html
[5]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#overview
[6]: https://www.nomadproject.io/guides/install/production/reference-architecture.html
[7]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#download-nomad
[8]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#install-nomad
[9]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#configure-systemd
[10]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#configure-nomad
[11]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#start-nomad
[12]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#download-nomad
[13]: https://releases.hashicorp.com/nomad/
[14]: https://www.hashicorp.com/security.html
[15]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#install-nomad
[16]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#configure-systemd
[17]: https://www.freedesktop.org/software/systemd/man/systemd.directives.html
[18]: https://www.freedesktop.org/software/systemd/man/systemd.unit.html#Description=
[19]: https://www.freedesktop.org/software/systemd/man/systemd.unit.html#Documentation=
[20]: https://www.freedesktop.org/software/systemd/man/systemd.unit.html#Wants=
[21]: https://www.freedesktop.org/software/systemd/man/systemd.unit.html#After=
[22]: https://www.freedesktop.org/software/systemd/man/systemd.service.html#ExecReload=
[23]: https://www.freedesktop.org/software/systemd/man/systemd.service.html#ExecStart=
[24]: https://www.freedesktop.org/software/systemd/man/systemd.kill.html#KillMode=
[25]: https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Process%20Properties
[26]: https://www.freedesktop.org/software/systemd/man/systemd.service.html#RestartSec=
[27]: https://www.freedesktop.org/software/systemd/man/systemd.service.html#Restart=
[28]: https://www.freedesktop.org/software/systemd/man/systemd.unit.html#StartLimitIntervalSec=interval
[29]: https://www.freedesktop.org/software/systemd/man/systemd.resource-control.html#TasksMax=N
[30]: https://www.freedesktop.org/software/systemd/man/systemd.unit.html#WantedBy=
[31]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#configure-nomad
[32]: https://www.nomadproject.io/docs/configuration/index.html
[33]: https://www.nomadproject.io/docs/configuration/index.html
[34]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#common-configuration
[35]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#server-configuration
[36]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#client-configuration
[37]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#common-configuration
[38]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#server-configuration
[39]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#client-configuration
[41]: https://www.nomadproject.io/docs/configuration/index.html#datacenter
[42]: https://www.nomadproject.io/docs/configuration/index.html#data_dir
[44]: https://www.nomadproject.io/docs/internals/consensus.html#deployment-table
[45]: https://www.nomadproject.io/docs/configuration/server.html#enabled
[46]: https://www.nomadproject.io/docs/configuration/server.html#bootstrap_expect
[48]: https://www.nomadproject.io/docs/configuration/client.html#enabled
[49]: https://www.nomadproject.io/docs/configuration/client.html#options-parameters
[51]: https://www.nomadproject.io/guides/security/acl.html
[52]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#tls-configuration
[53]: https://www.nomadproject.io/guides/security/securing-nomad.html
[54]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#start-nomad
[55]: https://www.nomadproject.io/guides/install/production/deployment-guide.html#next-steps
[56]: https://www.nomadproject.io/guides/operations/outage.html
[57]: https://www.nomadproject.io/guides/operations/autopilot.html
