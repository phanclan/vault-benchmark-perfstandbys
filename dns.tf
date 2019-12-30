# resource "aws_route53_record" "fabio" {
#   zone_id = var.zone_id
#    name    = "fabio.${var.namespace}"
#   #name    = "fabio"
#   type    = "CNAME"
#   records = [aws_alb.fabio.dns_name]
#   ttl     = "300"
# }
# resource "aws_route53_record" "consul" {
#   zone_id = var.zone_id
#    name    = "consul.${var.namespace}"
#   #name    = "consul"
#   type    = "CNAME"
#   records = [aws_alb.consul.dns_name]
#   ttl     = "300"
# }
# resource "aws_route53_record" "nomad" {
#   zone_id = var.zone_id
#   name    = "nomad.${var.namespace}"
#   // name    = "nomad"
#   type    = "CNAME"
#   records = [aws_alb.nomad.dns_name]
#   ttl     = "300"
# }

# --------------------------------------------------------
# CREATE A ROUTE 53 CNAME FOR THE ELB
# --------------------------------------------------------
resource "aws_route53_record" "vault" {
  zone_id = var.zone_id
  # name    = "vault.${var.namespace}"
  name = "vault"
  # type    = "CNAME"
  # ttl     = "300" 
  # records = [aws_elb.vault.dns_name]
  # records = [aws_elb.vault.zone_id]
  type = "A"
  alias {
    name                   = aws_elb.vault.dns_name
    zone_id                = aws_elb.vault.zone_id
    evaluate_target_health = true
  }
}
resource "aws_route53_record" "consul" {
  zone_id = var.zone_id
  #  name    = "consul.${var.namespace}"
  name = "consul"
  type = "A"
  alias {
    name                   = aws_elb.consul.dns_name
    zone_id                = aws_elb.consul.zone_id
    evaluate_target_health = true
  }
}

# resource "aws_route53_record" "servers" {
#   count = var.servers
#   zone_id = var.zone_id
#   name    = "server-${count.index}.${var.namespace}"
#   // name    = "server-${count.index}"
#   type    = "CNAME"
#   records = ["${element(aws_instance.servers.*.public_dns, count.index)}"]
#   ttl     = "300"
# }

# resource "aws_route53_record" "workers" {
#   count = var.workers
#   zone_id = var.zone_id
#   name    = "workers-${count.index}.${var.namespace}"
#   // name    = "workers-${count.index}"
#   type    = "CNAME"
#   records = ["${element(aws_instance.workers.*.public_dns, count.index)}"]
#   ttl     = "300"
# }

resource "aws_route53_record" "servers" {
  count   = 0
  zone_id = var.zone_id
  # name    = "server-${count.index}.${var.namespace}"
  name    = "server-${count.index}"
  type    = "CNAME"
  records = ["${element(aws_instance.servers.*.public_dns, count.index)}"]
  ttl     = "300"
}

resource "aws_route53_record" "workers" {
  count   = var.worker_nodes
  zone_id = var.zone_id
  # name    = "server-${count.index}.${var.namespace}"
  name    = "worker-${count.index}"
  type    = "CNAME"
  records = ["${element(aws_instance.workers.*.public_dns, count.index)}"]
  ttl     = "300"
}

resource "aws_route53_record" "hashi-vault" {
  count   = var.vault_nodes
  zone_id = var.zone_id
  # name    = "server-${count.index}.${var.namespace}"
  name    = "vault-${count.index}"
  type    = "CNAME"
  records = ["${element(aws_instance.vault.*.public_dns, count.index)}"]
  ttl     = "300"
}

resource "aws_route53_record" "hashi-bastion" {
  count   = var.bastion_nodes
  zone_id = var.zone_id
  name    = "bastion-${count.index}"
  type    = "CNAME"
  records = ["${element(module.bastion.bastion_pub_dns, count.index)}"]
  ttl     = "300"
}