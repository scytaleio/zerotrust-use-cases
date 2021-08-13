
resource "null_resource" "workloads-http-spire-entry" {
  provisioner "local-exec" {
    command = <<EOT
export KUBECONFIG=${var.kubeconfig}
export TRUST_DOMAIN=${var.trust_domain}
bash modules/workloads-http/create-registration-entries-http.sh
EOT
  }
}

