resource "kubernetes_namespace" "spire-vault" {
  metadata {
    labels = {
      app = "spire-vault"
    }
    name = "spire-vault"
  }
}

resource "kubernetes_service" "spire_vault" {
  metadata {
    name = "spire-vault"
    namespace = "spire-vault"

    labels = {
      app = "spire-vault"
    }
  }

  spec {
    port {
      name        = "spire-vault-tcp"
      protocol    = "TCP"
      port        = 8200
      target_port = "8200"
    }

    selector = {
      app = "spire-vault"
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_deployment" "spire_vault" {
  metadata {
    name      = "spire-vault"
    namespace = "spire-vault"

    labels = {
      app = "spire-vault"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "spire-vault"
      }
    }

    template {
      metadata {
        labels = {
          app = "spire-vault"
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
          name  = "vault"
          image = "vault"
          tty = true
          stdin = true

          env {
            name  = "VAULT_ADDR"
            value = "http://127.0.0.1:8200"
          }

          port {
            container_port = 8200
          }

          volume_mount {
            name       = "spire-agent-socket"
            read_only  = true
            mount_path = "/opt/spire/sockets"
          }
        }
      }
    }
  }
}

