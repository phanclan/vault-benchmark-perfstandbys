
output "A_Welcome_Message" {
  value = <<SHELLCOMMANDS

ooooo   ooooo                    oooo         o8o    .oooooo.
`888'   `888'                    `888         `"'   d8P'  `Y8b
 888     888   .oooo.    .oooo.o  888 .oo.   oooo  888           .ooooo.  oooo d8b oo.ooooo.
 888ooooo888  `P  )88b  d88(  "8  888P"Y88b  `888  888          d88' `88b `888""8P  888' `88b
 888     888   .oP"888  `"Y88b.   888   888   888  888          888   888  888      888   888
 888     888  d8(  888  o.  )88b  888   888   888  `88b    ooo  888   888  888      888   888
o888o   o888o `Y888""8o 8""888P' o888o o888o o888o  `Y8bood8P'  `Y8bod8P' d888b     888bod8P'
                                                                                    888
                                                                                   o888o
 |.--------_--_------------_--__--.|
 ||    /\ |_)|_)|   /\ | |(_ |_   ||
 ;;`,_/``\|__|__|__/``\|_| _)|__ ,:|
((_(-,-----------.-.----------.-.)`)
 \__ )        ,'     `.        \ _/
 :  :        |_________|       :  :
 |-'|       ,'-.-.--.-.`.      |`-|
 |_.|      (( (*  )(*  )))     |._|
 |  |       `.-`-'--`-'.'      |  |
 |-'|        | ,-.-.-. |       |._|
 |  |        |(|-|-|-|)|       |  |
 :,':        |_`-'-'-'_|       ;`.;
  \  \     ,'           `.    /._/
   \/ `._ /_______________\_,'  /
    \  / :   ___________   : \,'
     `.| |  |           |  |,'
       `.|  |           |  |
         |  | HashiCorp |  |
SHELLCOMMANDS
}

output "vault_address" {
  value = "http://${aws_elb.vault.dns_name}:8200"
}

output "vault_ui" {
  value = "http://${aws_route53_record.vault.fqdn}:8200"
}

output "consul_address" {
  value = "http://${aws_elb.consul.dns_name}:8500"
}

output "consul_ui" {
  value = "http://${aws_route53_record.consul.fqdn}:8500"
}

// Can be used to add additional SG rules to Vault instances.
output "vault_security_group" {
  value = aws_security_group.vault.id
}

// Can be used to add additional SG rules to the Vault ELB.
output "vault_elb_security_group" {
  value = aws_security_group.vault_elb.id
}

# output "primary_server_public_ips" {
#   value = [module.nomadconsul.primary_server_public_ips]
# }