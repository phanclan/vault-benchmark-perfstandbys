name: Vault-Benchmark-Performance-Standbys
class: center
count: false

# Vault Benchmark Performance Standbys
## Test performance on Vault

???
<!---
Notes
This slide presentation is stored as Markdown code, specifically using the RemarkJS engine to render it. All standard markdown tags are supported, and you can also use some HTML within this document.

If you need to change the look and feel of the slide deck just use the `style.css` and `remark_settings.js` files to suit your needs. The content in this file is picked up by `index.html` when the page is loaded.

HTML comments like this one will show up in the source code, but not in the slides or speaker notes.
--->
Welcome to the beginner's guide to Terraform on Azure. This slide deck is written entirely in Markdown language, which means you can make edits or additions, then submit a pull request to add your changes to the master copy. To make edits to the slide deck simply fork this repository, edit the Markdown files, and submit a pull request with your changes.

The Markdown content is contained in the docs/ subdirectories.

Here are some helpful keyboard shortcuts for the instructor or participant:

⬆ ⬇ ⬅ ➡ - Navigate back and forth
P         - Toggle presenter view
C         - Pop an external window for presentation

Instructor notes are included in plain text, narrative parts are in **bold**. You can use the narrative quotes or change them to suit your own presentation style.

---
layout: true

.footer[
- Copyright © 2019 HashiCorp
- ![:scale 100%](https://hashicorp.github.io/field-workshops-assets/assets/logos/HashiCorp_Icon_Black.svg)
]

---
name: Link-to-Slide-Deck
# The Slide Deck
<br><br>
Follow along on your own computer at this link:

# https://git.io/JeuCI

---
name: Introductions
# Introductions
* Your Name
* Job Title
* Automation Experience
* Favorite Text Editor

???
Use this slide to introduce yourself, give a little bit of your background story, then go around the room and have all your participants introduce themselves.

The favorite text editor question is a good ice breaker, but perhaps more importantly it gives you an immediate gauge of how technical your users are.

**There are no wrong answers to this question. Unless you say Notepad. Friends don't let friends write code in Notepad.**

**If you don't have a favorite text editor, that's okay! Our cloud lab has Visual Studio Code preinstalled. VSC is a free programmer's text editor for Microsoft, and it has great Terraform support. Most of this workshop will be simply copying and pasting code, so if you're not a developer don't fret. Terraform is easy to learn and fun to work with.**

---
name: Table-of-Contents
# Table of Contents

1. Intro to Terraform & Demo<br>
1. Terraform Basics<br>
👩‍🔬 **Lab - Setup and Basic Usage**<br>
1. Terraform In Action: plan, apply, destroy<br>
1. Organizing Your Terraform Code<br>
🧪 **Lab - Terraform in Action**<br>
1. Provision and Configure Azure VMs<br>
🔬 **Lab - Provisioning with Terraform**<br>
1. Manage and Change Infrastructure State<br>
1. Terraform Cloud<br>
⚗️ **Lab - Terraform Remote State**


???
This workshop should take roughly three hours to complete.

**Here is our agenda for today's training. The format is simple, you'll hear a lecture and view slides on each topic, then participate in a hands-on lab about that topic. We'll alternate between lecture and lab, with a couple of breaks thrown in.**

---
name: intro-to-terraform-demo
class: title
# Chapter 1
## Introduction to Terraform

???
We use the word chapter here, because the training should feel like a story unfolding. The instructor's job is to guide the learners through this interactive story.


# 
# Deploy Vault to AWS with Consul Storage Backend

This folder contains a Terraform module for deploying Vault to AWS (within a VPC) along with Consul as the storage backend. It can be used as-is or can be modified to work in your scenario, but should serve as a strong starting point for deploying Vault. It can be used with Ubuntu 16.04 or RHEL 7.5.

---

The Terraform code will create the following resources in a VPC and subnet that you specify in the AWS us-east-1 region:

* IAM instance profile, IAM role, IAM policy, and associated IAM policy documents
* An AWS auto scaling group with 3 EC2 instances running Vault on RHEL 7.5 or Ubuntu 16.04 (depending on the AMI passed to the ami variable)
* An AWS auto scaling group with 3 EC2 instances running Consul on RHEL 7.5 or Ubuntu 16.04 (depending on the AMI passed to the ami variable)
* 2 AWS launch configurations
* 2 AWS Elastic Load Balancers, one for Vault and one for Consul
* 2 AWS security groups, one for the Vault and Consul EC2 instances and one for the ELBs.
* Security Group Rules to control ingress and egress for the instances and the ELBs. These attempt to limit most traffic to inside and between the two security groups, but do allow the following broader access:
  - inbound SSH access on port 22 from anywhere
  - inbound access to the ELBs on ports 8200 for Vault and 8500 for Consul
  - outbound calls on port 443 to anywhere (so that the installation scripts can download the vault and consul binaries)
  - After installation, those broader security group rules could be made tighter.

---

You can deploy this in either a public or a private subnet.  But you must set `elb_internal` and `public_ip` as instructed below in both cases. The VPC should have at least one subnet with 2 or 3 being preferred for high availability.

Note that the `create-iam-and-sgs` branch of this repository can be used to create the IAM and security group resources separately. If you do use that, you can then use the `asgs-instances-elbs` branch to create the auto scaling groups, EC2 instances, and ELBs.

Note that if using the HTTP download links for the evaulation binaries of Vault Enterprise and Consul Enterprise, you will need to apply license files for both of these. See more below. Note, however, that you could use Consul Open Source instead of Consul Enterprise with no loss of functionality. In that case, you would change the `consul_download_url` to https://releases.hashicorp.com/consul/1.5.0/consul_1.5.0_linux_amd64.zip.

---

**The licenses must be applied within 30 minutes after starting the servers**. If you don't do this, you will need to restart them and then apply the licenses within 30 minutes.

---
name: Preparation
class: compact
## Preparation
1. Download [terraform](https://www.terraform.io/downloads.html) and extract the terraform .small[binary] to some directory in your path.
1. Clone this repository to some directory on your laptop
1. On a Linux or Mac system, export your AWS keys and AWS default region as variables. On Windows, you would use `set` instead of `export`. You can also `export AWS_SESSION_TOKEN` if you need to use an MFA token to provision resources in AWS.

---

```shell
export AWS_ACCESS_KEY_ID=<your_aws_key>
export AWS_SECRET_ACCESS_KEY=<your_aws_secret_key>
export AWS_DEFAULT_REGION=us-east-1
export AWS_SESSION_TOKEN=<your_token>
```
4. Edit the file `vault.auto.tfvars` and provide values for the variables at the top of the file that do not yet have values.

    - Be sure to set `unzip_command` to the appropriate command for Ubuntu or RHEL, depending on your AMI.
    - Set `ami` to the ID of a Ubuntu 16.04 or RHEL 7.5 AMI. Public Ubuntu AMIs include `ami-759bc50a` or `ami-059eeca93cf09eebd`.  A public RHEL 7.5 AMI is `ami-6871a115`.
    - Set `instance_type` to the size you want to use for the EC2 instances.
    - `key_name` should be the name of an existing AWS keypair in your AWS account in the `us-east-1` region. Use the name as it is shown in the AWS Console, not the name of the private key on your computer.  Of course, you'll need that private key file in order to ssh to the Vault instance that is created for you.
    - `vault_name_prefix` and `consul_name_prefix` can be anything you want; they affect the names of some of the resources.
    - `vpc_id` should be the id of the VPC into which you want to deploy Vault.
    - `subnets` should be the ids of one or more subnets in your AWS VPC in `us-east-1`. (You can also list multiple subnets and separate them with commas, but you only need one.)

      If using a public subnet, use the following for `elb_internal` and `public_ip`:
      - `elb_internal = false`
      - `public_ip = true`

      If using a private subnet, use the following for `elb_internal` and `public_ip`:
      - `elb_internal = true`
      - `public_ip = false`
    - NOTE: Do not add quotes around true and false when setting `elb_internal` and `public_ip`.
    - The `owner` and `ttl` variables are intended for use by HashiCorp employees and will be ignored for customers.  You can set `owner` to your name or email.

---

## Deployment
To actually deploy with Terraform, simply run the following two commands:

```
terraform init
terraform apply
```

When the second command asks you if you want to proceed, type "`yes`" to confirm.

You should get outputs at the end of the apply showing something like the following:

```tex
Outputs:
consul_address = benchmark-consul-elb-387787750.us-east-1.elb.amazonaws.com
vault_address = benchmark-vault-elb-783003639.us-east-1.elb.amazonaws.com
vault_elb_security_group = sg-09ee1199992b803f7
vault_security_group = sg-0a4c0e2f499e2e0cf
```

You will be able to use the Vault ELB URL after Vault is initialized which you will do as follows:

1. In the **AWS Console**, find and select your Vault instances and pick one.
1. Click the **Connect** button for your selected Vault instance to find the command you can use to ssh to the instance.
1. From a directory containing your private SSH key, run that ssh command.

Alternatively...
1. Find the public IP of a Vault instance via CLI.
```
aws --region us-west-2 \
  ec2 describe-instances --filter Name=tag-key,Values=aws:autoscaling:groupName \
  --query 'Reservations[*].Instances[*].{Instance:InstanceId,AZ:Placement.AvailabilityZone,Name:Tags[?Key==`Name`]|[0].Value,PIP:PublicIpAddress}' \
  --output text | grep pphan | grep -iv "None" | tee /tmp/describe-instances.txt
```
- Sample Output
```
us-west-2a	i-09c3966f19182ccaf	pphan-benchmark-consul	34.210.58.127
us-west-2b	i-0eefe1616ca431997	pphan-benchmark-consul	52.12.105.181
us-west-2b	i-04883a05926eb4f89	pphan-benchmark-vault	34.221.221.30
us-west-2c	i-09ee3f9e1642847be	pphan-benchmark-consul	34.213.76.192
```
2. SSH to Vault Public IP
```
ssh ubuntu@34.221.221.30
# or 
ssh ubuntu@$(grep vault /tmp/describe-instances.txt | grep -iv "None" | awk '{print $NF}')
```
3. Run the following command.
```
export VAULT_ADDR=http://$(grep vault /tmp/describe-instances.txt | grep -iv "None" | awk '{print $NF}'):8200
export CONSUL_HTTP_ADDR=$(terraform output | grep consul_ui | awk '{print $NF}')
```

1. On the Vault server, run the following commands:
```
#export VAULT_ADDR=http://127.0.0.1:8200
#vault operator init -key-shares=1 -key-threshold=1 > /tmp/vault.init

export CONSUL_HTTP_ADDR=http://pphan-benchmark-consul-elb-1195120718.us-west-2.elb.amazonaws.com:8500
vault operator init -key-shares=1 -key-threshold=1 -format=json | tee /tmp/vault.init
jq -r ".unseal_keys_b64[0]" /tmp/vault.init | consul kv put service/vault/recovery-key -
jq -r ".root_token" /tmp/vault.init | consul kv put service/vault/root-token -
curl -X PUT -d '{"key": "'"$(consul kv get service/vault/recovery-key)"'"}' \
    ${VAULT_ADDR}/v1/sys/unseal
export VAULT_TOKEN=$(consul kv get service/vault/root-token)
curl -H "X-Vault-Token: $VAULT_TOKEN" -X PUT -d @/license/licensepayload.json $VAULT_ADDR/v1/sys/license
```

Save the values for **Unseal Key** and **Initial Root Token**. Example:

```
Unseal Key 1: jxWdVApsw6FHCTfx5PwG0nn7v/rrEpk1uv0XYyF5xOs=
Initial Root Token: s.8aQruVrp9YJ834NLCvjVCNcZ
```

The init command will show you your root token and unseal key. (In a real production environment, you would specify `-key-shares=5 -key-threshold=3`.)

```
export VAULT_TOKEN=<your_root_token>
vault operator unseal
```

Provide your unseal key when prompted. If you selected a key-threshold greater than 1, repeat the last command until the first Vault instance is unsealed.

- If installing evaluation Vault Enterprise and Consul Enterprise binaries, please apply the Vault and Consul license files given to you by HashiCorp.

```
vault write sys/license text=<contents_of_vault_license_file>
consul license put "<contents_of_consul_license_file>"
```

- To avoid having to export `VAULT_ADDR` and `VAULT_TOKEN` in future SSH sessions, edit `/home/ubuntu/.profile`, `/home/ubuntu/.bash_profile`, and/or `/home/ec2-user/.bash_profile` and add the two export commands at the bottom.

## Unseal Second and Third Nodes
Please do the following additional steps for your second and third Vault nodes:

1. In the AWS Console, find and select your instances and pick the second (or third) one.
1. Click the **Connect** button for your EC2 instance in the AWS console to find the command you can use to ssh to the instance.
1. From a directory containing your private SSH key, run that ssh command.
1. On the Vault server, run the following commands:

```
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=<your_root_token>
vault operator unseal
```

For the last command, provide your unseal key. If you selected a `key-threshold` greater than `1`, repeat the last command until the Vault instance is unsealed.

**Remember to repeat the last set of steps for the third instance.**

Your Vault and Consul Servers are now set up and licensed.  Additionally, it is running Consul as Vault's storage backend.  You can confirm that both Vault and Consul are running with the commands `ps -ef | grep vault` and `ps -ef | grep consul`.  But if you were able to access the Vault UI, you already know both are running.

Now that you have initialized Vault, you can actually access the Vault UI using your Vault ELB: `http://<Vault_ELB_address>:8200/ui`.

You can also access your Consul UI through the Consul ELB: `http://<Consul_ELB_address>:8500/ui`.

# Running a Benchmark

This repo is designed to work with the following tools:

* https://github.com/wg/wrk
* https://github.com/giltene/wrk2

More detailed test scripts can be found here: https://github.com/hashicorp/vault-guides/tree/master/operations/benchmarking/wrk-core-vault-operations

Depending on the level of concurrency you use you may need to adjust the `ulimit` when running `wrk/wrk2` on either the benchmark server or your remote machine. Using both of these tools together can provide a holistic assessment of both stress and load capabilities of your cluster.

Below are examples of a valid `wrk/wrk2` tests that you could run from the benchmark server. This test is simple and would read a KV entry from Vault. We've given Envoy a static private IP but you could also resolve it with Consul DNS.

10k concurrent connections for 5 minutes for max RPS & 10s timeout & latency stats.<br/>
`wrk -t4 -c10000 -d300s --latency  --timeout 10s --header 'X-VAULT-TOKEN: <token>'  'https://10.0.1.20:8443/v1/secret/foo'`

`wrk -t4 -c10000 -d10s --latency  --timeout 5s --header 'X-VAULT-TOKEN: ${VAULT_TOKEN}'  'http://127.0.0.1:8200/v1/secrets/foo'`

wrk -t4 -c16 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-random-secrets.lua http://127.0.0.1:8200 -- 10000 > prod-test-write-1000-random-secrets-t4-c16-1hour.log &

wrk -t1 -c1 -d30s -H "X-Vault-Token: $VAULT_TOKEN" -s write-secrets.lua http://127.0.0.1:8200 -- 1000

10k concurrent connections for 5 minutes for 5k target RPS & 10s timeout & latency stats.<br/>
`wrk2 -t4 -R5000 -c10000 -d300s --latency  --timeout 10s --header 'X-VAULT-TOKEN: <token>'  'https://10.0.1.20:8443/v1/secret/foo'`


# Transit Test

We will use the `wrk` benchmarking tool to test the throughput of HashiCorp Vault's transit backend. 
I tested on a single Vault node, connected to a 3-node Consul cluster for backend storage. Only the transit engine is mounted.

- Enable the Transit secret engine and write a keyring for your testing:

```
vault secrets enable -path=transit transit
vault write -f transit/keys/test
```

- Clone Jacob Friedman's repo, which contains our testing scripts for Vault Transit.

```
git clone https://github.com/jdfriedma/Vault-Transit-Load-Testing.git
```

- Install **wrk** on load generation machine: https://github.com/wg/wrk/wiki/Installing-Wrk-on-Linux

```
sudo apt-get install build-essential libssl-dev git -y
git clone https://github.com/wg/wrk.git wrk
cd wrk
make
# move the executable to somewhere in your PATH, ex:
sudo cp wrk /usr/local/bin
```

- Run your workload. 
  - The makers of wrk recommend running a **maximum of 1 thread per core**. 
    - t3.nano - large has 2 vCPU, so 2 threads
    - t3.xlarge has 4 vCPU, t3.2xlarge has 8 vCPU
    - c5.xlarge has 4 vCPU, 2xlarge has 8 vCPU
  - Play around with the number of connections you use to determine what the ideal settings for your system are. The connections are a total number of connections, split across your threads, as described here: https://github.com/wg/wrk#command-line-options 
  - A sample `wrk` command to run these files looks like this: 
    `wrk -t8 -c8 -d1m -H "X-Vault-Token: TOKEN_GOES_HERE_SO_PASTE_IT" -s /home/ubuntu/postbatch320.lua http://10.0.0.50:8200/v1/transit/encrypt/test` 
    - where the IP and path correspond to the Transit secret engine you'd configured.
  - Sample
    ```
    cd ~/Vault-Transit-Load-Testing/
    wrk -t2 -c8 -d30s -H "X-Vault-Token: ${VAULT_TOKEN}" -s postbatch320.lua http://localhost:8200/v1/transit/encrypt/test
    ```

# Sizing up (or down)
I started with a t3.small and then scaled up to a c5.2xlarge.

Here are the steps to resize your vault server.

1. Change `instance_type_vault` and run `terraform apply`.
1. ssh into vault.
1. Run `vault operator unseal` and provide unseal key.
1. Run the following commands:
```
tee test.sh <<"EOF"
#!/bin/bash -x
#------------------------------------------------------------------------------
git clone https://github.com/hashicorp/vault-guides.git
#------------------------------------------------------------------------------
sudo apt-get install build-essential libssl-dev git -y
cd ~
git clone https://github.com/wg/wrk.git wrk
cd ~/wrk
make
# move the executable to somewhere in your PATH, ex:
sudo cp wrk /usr/local/bin
#------------------------------------------------------------------------------
cd ~
git clone https://github.com/jdfriedma/Vault-Transit-Load-Testing.git
#------------------------------------------------------------------------------
cd ~/Vault-Transit-Load-Testing/
for i in 320 160; do
echo "# postbatch${i}.lua on $(date)" > postbatch-${i}.log
echo wrk -t2 -c8 -d120s -H "X-Vault-Token: ${VAULT_TOKEN}" -s postbatch${i}.lua http://localhost:8200/v1/transit/encrypt/test
wrk -t2 -c8 -d120s -H "X-Vault-Token: ${VAULT_TOKEN}" -s postbatch${i}.lua http://localhost:8200/v1/transit/encrypt/test >> postbatch-${i}.log
done
EOF
chmod +x test.sh
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=s.8aQruVrp9YJ834NLCvjVCNcZ
vault operator unseal jxWdVApsw6FHCTfx5PwG0nn7v/rrEpk1uv0XYyF5xOs=
vault audit enable file file_path=/tmp/audit.log log_raw=true
./test.sh
```


# Sample Results

## Results on Vault 1-node t3.large with Consul 3-node t3-small

```
# postbatch160.lua on Fri Dec 13 05:14:31 UTC 2019
Running 2m test @ http://localhost:8200/v1/transit/encrypt/test
  2 threads and 8 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    31.10ms   36.71ms 382.74ms   87.11%
    Req/Sec   187.59     53.00   414.00     68.40%
  44877 requests in 2.00m, 609.91MB read
Requests/sec:    373.72
Transfer/sec:      5.08MB
# postbatch320.lua on Fri Dec 13 05:12:31 UTC 2019
Running 2m test @ http://localhost:8200/v1/transit/encrypt/test
  2 threads and 8 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    48.11ms   42.41ms 424.39ms   85.66%
    Req/Sec    98.01     28.43   212.00     73.29%
  23470 requests in 2.00m, 630.54MB read
Requests/sec:    195.44
Transfer/sec:      5.25MB
```

## Results: Vault 1-node t3.xlarge; Consul 3-node t3-small; Audit On

```
# postbatch160.lua on Fri Dec 13 04:33:38 UTC 2019
Running 30s test @ http://localhost:8200/v1/transit/encrypt/test
  2 threads and 8 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    12.12ms    8.79ms  77.53ms   86.35%
    Req/Sec   363.37     37.61   474.00     67.67%
  21719 requests in 30.02s, 295.18MB read
Requests/sec:    723.53
Transfer/sec:      9.83MB
# postbatch320.lua on Fri Dec 13 04:33:08 UTC 2019
Running 30s test @ http://localhost:8200/v1/transit/encrypt/test
  2 threads and 8 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    22.13ms   13.41ms 120.43ms   71.08%
    Req/Sec   189.34     23.65   292.00     71.00%
  11325 requests in 30.02s, 304.26MB read
Requests/sec:    377.23
Transfer/sec:     10.13MB
```

## Results: Vault 1-node c5.xlarge; Consul 3-node t3-small; Audit On
```
# postbatch160.lua on Fri Dec 13 04:05:34 UTC 2019
Running 30s test @ http://localhost:8200/v1/transit/encrypt/test
  2 threads and 8 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    10.88ms    7.90ms  65.21ms   86.49%
    Req/Sec   404.98     43.91   525.00     64.33%
  24205 requests in 30.02s, 328.97MB read
Requests/sec:    806.30
Transfer/sec:     10.96MB

# postbatch320.lua on Fri Dec 13 04:05:04 UTC 2019
Running 30s test @ http://localhost:8200/v1/transit/encrypt/test
  2 threads and 8 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    19.72ms   11.83ms  98.90ms   71.10%
    Req/Sec   212.34     24.64   300.00     69.67%
  12695 requests in 30.02s, 341.06MB read
Requests/sec:    422.92
Transfer/sec:     11.36MB
```

## Results: Vault 1-node c5.2xlarge with Consul 3-node t3-small; Auditing Off
```
$ wrk -t2 -c8 -d30s -H "X-Vault-Token: ${VAULT_TOKEN}" -s single-key-post.lua http://localhost:8200/v1/transit/encrypt/test
Running 30s test @ http://localhost:8200/v1/transit/encrypt/test
  2 threads and 8 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   329.15us  329.62us  13.35ms   94.57%
    Req/Sec    13.43k   724.40    15.02k    62.13%
  804771 requests in 30.10s, 290.11MB read
Requests/sec:  26736.87
Transfer/sec:      9.64MB
```

## Results on Vault 1-node c5.2xlarge with Consul 3-node t3-small; Auditing On
```
$ wrk -t2 -c8 -d30s -H "X-Vault-Token: ${VAULT_TOKEN}" -s single-key-post.lua http://localhost:8200/v1/transit/encrypt/test
Running 30s test @ http://localhost:8200/v1/transit/encrypt/test
  2 threads and 8 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   414.21us  335.91us  14.75ms   94.17%
    Req/Sec    10.26k   443.20    11.17k    60.30%
  614607 requests in 30.10s, 221.56MB read
Requests/sec:  20418.74
Transfer/sec:      7.36MB
```

## Sample Response from Audit Log with Raw Output
```
sudo tail -n 50 /tmp/audit.log | jq
{
  "time": "2019-12-13T02:12:13.917000292Z",
  "type": "response",
  "auth": {
    "client_token": "s.8aQruVrp9YJ834NLCvjVCNcZ",
    "accessor": "fLhKSoUgIneQlgFXHDoWkkBu",
    "display_name": "root",
    "policies": [
      "root"
    ],
    "token_policies": [
      "root"
    ],
    "token_type": "service"
  },
  "request": {
    "id": "c970976c-f130-b17d-1da9-0dc22876f8f2",
    "operation": "update",
    "client_token": "s.8aQruVrp9YJ834NLCvjVCNcZ",
    "client_token_accessor": "fLhKSoUgIneQlgFXHDoWkkBu",
    "namespace": {
      "id": "root"
    },
    "path": "transit/encrypt/test",
    "data": {
      "plaintext": "dGVldkV0R2ZodVV5Yk9zUA=="
    },
    "remote_address": "127.0.0.1"
  },
  "response": {
    "data": {
      "ciphertext": "vault:v1:ltmfMcAU0k1Gm/+WRjva+76ZmdHhjj1dQ674X7BYw24L8ShF5HDGMkC9jYI="
    }
  }
}
```

