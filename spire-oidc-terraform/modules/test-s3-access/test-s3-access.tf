resource "kubernetes_namespace" "spire-oidc" {
  metadata {
    labels = {
      app = "oidc-client"
    }
    name = "spire-oidc"
  }
}

resource "kubernetes_deployment" "oidc-client" {
  metadata {
    name = "oidc-client"
    namespace = "spire-oidc"

    labels = {
      app = "oidc-client"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "oidc-client"
      }
    }

    template {
      metadata {
        labels = {
          app = "oidc-client"
        }
      }

      spec {
        volume {
          name = "spire-agent-socket"

          host_path {
            path = "/opt/spire/sockets"
            type = "Directory"
          }
        }

        container {
          name    = "oidc-client"
          image   = "gcr.io/spiffe-io/spire-agent:1.0.0"
          command = ["sleep"]
          args    = ["1000000000"]

          volume_mount {
            name       = "spire-agent-socket"
            read_only  = true
            mount_path = "/opt/spire/sockets"
          }
        }

        dns_policy   = "ClusterFirstWithHostNet"
        host_network = true
        host_pid     = true
      }
    }
  }
}

resource "null_resource" "test-s3-access" {
  provisioner "local-exec" {
    command = <<EOT
export KUBECONFIG=${var.kubeconfig}
bash -x ${path.module}/test-s3-access.sh ${var.trust_domain} ${var.oidc_role_arn} ${var.s3_bucket_name}
EOT
  }
  depends_on = [kubernetes_deployment.oidc-client]
}

