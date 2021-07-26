resource "null_resource" "workloads-tcp-spire-entry" {
  provisioner "local-exec" {
    command = "bash modules/workloads-tcp/create-registration-entries-tcp.sh"
  }
}

