
name: terraform
class: title, shelf, no-footer, fullbleed
background-image: url(https://hashicorp.github.io/field-workshops-assets/assets/bkgs/HashiCorp-Title-bkg.jpeg)

# Terraform

---
name: terraform-loadbalancer-aws-config
class: compact, col-2

# Network Load Balancer with Terraform

.smaller[
- `aws_lb`: Creates load balancer (LB) resource. To create network load balancer (NLB), load balancer type `network` has to be specified.
  - To specify  elastic IP the subnet_mapping block has to be included.
  - NOTE: Changing `elastic IP` or `subnet` of the NLB destroys and recreates the LB.]

```go
subnet_mapping {
    subnet_id     = "${aws_subnet.test_subnet.id}"
    allocation_id = "${aws_eip.test_subnet.id}"
  }
```

.smaller[
- `aws_lb_listener`: Creates load balancer `listener`. Three required arguments for creating resource are: `port`, `protocol`, and `default action`
- `aws_lb_target_group`: Creates `Target Group` resource to serve requests sent from LB. `target_type` can be `IP`, `instance` or `lambda`.
  - Changing the `target_type` forces recreation of resource
- `aws_lb_target_group_attachment`: Attaches targets to target group.
  - All targets running same service should belong in same target group by specifying the `target_id`, port to be linked to the `target_group_arn`]

---
class: compact, col-2

.smaller[
The module structure is as follows
]

```shell
 — nlb (folder)
   -- nlb.tf
   -- variables.tf
   -- output.tf (optional)
```

---
class:compact, col-2

# lb.tf - File that defines the resources

```go
//nlb.tf
resource "aws_eip" "eip_nlb" {
  tags    = {
    Name  = "test-network-lb-eip"
    Env   = "test"
  }
}
resource "aws_lb" "load_balancer" {
  name                              = "test-network-lb" #can also be obtained from the variable nlb_config
  load_balancer_type                = "network"
  subnet_mapping {
    subnet_id     = lookup(var.nlb_config,"subnet")
    allocation_id = aws_eip.eip_nlb.id
  }
  tags = {
    Environment = lookup(var.nlb_config,"environment")
  }
}
resource "aws_lb_listener" "listener" {
  load_balancer_arn       = aws_lb.load_balancer.arn
  for_each = var.forwarding_config
    port                = each.key
    protocol            = each.value
    default_action {
      target_group_arn = "${aws_lb_target_group.tg[each.key].arn}"
      type             = "forward"
    }
}
```

```go
resource "aws_lb_target_group" "tg" {
  for_each = var.forwarding_config
    name                  = "${lookup(var.nlb_config, "environment")}-tg-${lookup(var.tg_config, "name")}-${each.key}"
    port                  = each.key
    protocol              = each.value
  vpc_id                  = lookup(var.tg_config, "tg_vpc_id")
  target_type             = lookup(var.tg_config, "target_type")
  deregistration_delay    = 90
  health_check {
      interval            = 60
      port                = each.value != "TCP_UDP" ? each.key : 80
      protocol            = "TCP"
      healthy_threshold   = 3
      unhealthy_threshold = 3
    }
  tags = {
    Environment = "test"
  }
}

resource "aws_lb_target_group_attachment" "tga1" {
  for_each = var.forwarding_config
    target_group_arn  = "${aws_lb_target_group.tg[each.key].arn}"
    port              = each.key
  target_id           = lookup(var.tg_config,"target_id1")
}
```

???
.smaller[
Special mention about using the `for_each` function released in `terraform 0.12`. It has been amazing and seems to be a perfect replacement for the count issues encountered with previous terraform versions. I was actually surprised that I could get an ARN from the target I created previously passing each.key to the resource.]

```go
# totally amazed by this! thanks to Terraform 0.12!
for_each = var.forwarding_config
    target_group_arn  = "${aws_lb_target_group.tg[each.key].arn}"
```

---
class: compact, col-2

.smaller[
Declaration of variables is done in `variables.tf`]

```go
// variables.tf
variable "nlb_config" {
  type = "map"
}
variable "tg_config" {
  type = "map"
}
variable "forwarding_config" {
}
```

.smaller[
The module can be initialized in a separate file at the terraform root level (the place where .terraform folder gets created when you run terraform init)]

```shell
-- test (folder)
  -- .terraform
  -- variables.tf
  -- provider.tf
*  -- test_nlb.tf
```

.smaller[
The module initializing can be done in one single file or multiple terraform files in the terraform root. Example Initialization:]

```go
//test_nlb.tf
module "network_lb" {
  source                   = "../modules/nlb"
  nlb_config               = var.test_nlb_config
  forwarding_config        = var.test_forwarding_config
  tg_config                = var.test_tg_config
}
```

---
class: compact, col-2

.smaller[
The `variables.tf` is a very crucial file that contains needful information for creating all the above resources.]

```go
# variables.tf
variable "test_nlb_config" {
  default = {
    name            = "test-nlb"
    internal        = "false"
    environment     = "test"
    subnet          = <subnet_id>
    nlb_vpc_id      = <vpc_id>
  }
}

variable "test_tg_config" {
  default = {
    name                              = "test-nlb-tg"
    target_type                       = "instance"
    health_check_protocol             = "TCP"
    tg_vpc_id                         = <tg_creation_vpc_id>
    target_id1                        = <one of instance_id/ip/arn>
  }
}

variable "test_forwarding_config" {
  default = {
      80        =   "TCP"
      443       =   "TCP" # and so on  }
}
```

---
name: terraform-loadbalancer-aws
class: compact, col-2

# Loadbalancer components

.smaller[
- `listeners`: Listens to incoming connection based on port and protocol
  - forward requests to `target group`
  - Supports TCP, TLS, UDP, TCP_UDP
  - `Rules` determine how load balancer routes request to its targets.
  - `Rule` can include one of these actions:
      - forward, redirect, fixed response
  - `forward` action: set up `target group`; requests matching `listening port` forwarded to `target group`
- `target groups`: distributes load among its targets
  - has to be created per service
  - target running that service has to be linked to target group
- `targets`: nodes which serve requests sent to load balancer
  - One target per AZ should be healthy if load balancer spans multiple AZs in region
  - Targets belonging to same target group have to run same service
  - target can be part of multiple target groups
  - targets can be linked based on IP adress or instance ID or ARN (lambda functions)
]

---
class: compact, col-2

.smaller[
- `Health Checks`: The LB periodically sends requests to its registered targets to ensure that they are healthy.
  - After target registered, health checks initialize
  - if target is healthy, LB sends requests to it.
  - For targets configured to be part of `target group` serving forwarded TCP requests, the port of each serving target has to be configured for a health check with the protocol being TCP.
- `UDP targets health check`: Health check for UDP targets cannot really be performed on the same port as the target because health checks only accept TCP, HTTP, and HTTPS.
  - for UDP, health checks have to be performed on any other open port.
  - By convention, all the UDP health checks are performed on `port 80`.
  - While we are at UDP requests, there is one more limitation for the load balancer.
      - To enable load balancing UDP requests, the target type should be an `instance_id`, not an IP or lambda
- `Cross Zone Availability`: If set, good practice to have at least one healthy target in each of the availability zones.
- `Elastic IP`: Load balancer can be attached with one Elastic IP per availability zone if cross-zone availability is set up or just one Elastic IP if served within the same availability zone. The IP address cannot be changed for a load balancer unless deleted and recreated.
]