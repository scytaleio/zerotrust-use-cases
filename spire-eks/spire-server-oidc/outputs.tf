output "spire_oidc_lb" {
  description = "Spire OIDC ELB"
  value = data.external.get_spire_oidc_lb.result.elb
}

output "spire_oidc_lbname" {
  description = "Spire OIDC ELB Name"
  value = data.external.get_spire_oidc_lb.result.elbName
}



