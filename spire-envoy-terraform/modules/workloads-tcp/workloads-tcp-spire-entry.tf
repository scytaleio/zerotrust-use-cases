
resource "null_resource" "workloads-tcp-spire-entry" {
  provisioner "local-exec" {
    command = <<EOT
export KUBECONFIG=${var.kubeconfig}
export TRUST_DOMAIN=${var.trust_domain}
bash modules/workloads-tcp/create-registration-entries-tcp.sh
EOT

  }
}

