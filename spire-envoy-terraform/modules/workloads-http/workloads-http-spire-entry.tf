resource "null_resource" "workloads-http-spire-entry" {
  provisioner "local-exec" {
    command = "bash modules/workloads-http/create-registration-entries-http.sh"
  }
}

