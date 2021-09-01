
resource "null_resource" "vault-configuration" {
  provisioner "local-exec" {
    command = <<EOT
export KUBECONFIG=${var.kubeconfig}
bash -x modules/vault-configure/vault-configure.sh ${var.trust_domain}
EOT
  }
}

