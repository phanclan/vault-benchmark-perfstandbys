output "mini_vault_r53" {
  value = aws_route53_record.this1.*.fqdn
}

output "mini_consul_r53" {
  value = aws_route53_record.this2.*.fqdn
}


output "minihashi_pub_dns" {
  value = aws_instance.vault.*.public_dns
}