`-ui` enable the UI
- \# Following folders are ephemeral: data_dir
- \# Following folders are mounted: /consul/config, 

- `server` switch - Providing this flag specifies that we want the agent to start in server mode.
- `-bootstrap-expect` flag - This tells the Consul server how many servers the datacenter should have in total. All the servers will wait for this number to join before bootstrapping the replicated log, which keeps data consistent across all the servers. Because you are setting up a one-server datacenter, you'll set this value to `1`. You can read more about this process in the bootstrapping guide.
  https://www.consul.io/docs/guides/bootstrapping.html
- `-node` name - Each node in a datacenter must have a unique name. By default, Consul uses the hostname of the machine, but we'll manually override it, and set it to `agent-one`.
- `-bind address` - This is the address that this agent will listen on for communication from other cluster members. It must be accessible by all other nodes in the datacenter. If you don't set a bind address Consul will try to listen on all IPv4 interfaces and will fail to start if it finds multiple private IPs. Since production servers often have multiple interfaces, you should always provide a bind address. In this case it is `172.20.20.10`, which you specified as the address of the first VM in your Vagrantfile.
- `data-dir` flag - This flag tells Consul agents where they should store their state, which can include sensitive data like ACL tokens for both servers and clients. In production deployments you should be careful about the permissions for this directory. Find more information in the documentation. You will set the data directory to a standard location: `/tmp/consul`.
- `config-dir` flag - This flag tells consul where to look for its configuration. You will set it to a standard location: `/etc/consul.d`.