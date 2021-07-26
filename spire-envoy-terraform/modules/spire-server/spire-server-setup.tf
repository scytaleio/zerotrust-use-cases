resource "kubernetes_namespace" "spire" {
  metadata {
    labels = {
      app = "http-workloads"
    }
    name = "spire"
  }
}

resource "kubernetes_service_account" "spire_server" {
  metadata {
    name      = "spire-server"
    namespace = "spire"
  }
  automount_service_account_token = true
  depends_on = [kubernetes_namespace.spire]
}

resource "kubernetes_cluster_role" "spire_server_trust_role" {
  metadata {
    name = "spire-server-trust-role"
  }

  rule {
    verbs      = ["create"]
    api_groups = ["authentication.k8s.io"]
    resources  = ["tokenreviews"]
  }

  rule {
    verbs      = ["patch", "get", "list"]
    api_groups = [""]
    resources  = ["configmaps"]
  }
}

resource "kubernetes_cluster_role_binding" "spire_server_trust_role_binding" {
  metadata {
    name = "spire-server-trust-role-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "spire-server"
    namespace = "spire"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "spire-server-trust-role"
  }
}

resource "kubernetes_config_map" "spire_bundle" {
  metadata {
    name      = "spire-bundle"
    namespace = "spire"
  }
  depends_on = [kubernetes_namespace.spire]
}

resource "kubernetes_config_map" "spire_server" {
  metadata {
    name      = "spire-server"
    namespace = "spire"
  }

  data = {
    "server.conf" = "server {\n  bind_address = \"0.0.0.0\"\n  bind_port = \"8081\"\n  registration_uds_path = \"/tmp/spire-registration.sock\"\n  trust_domain = \"envoy.spire-test.com\"\n  data_dir = \"/opt/spire/data\"\n  log_level = \"DEBUG\"\n  #AWS requires the use of RSA.  EC cryptography is not supported\n  ca_key_type = \"rsa-2048\"\n\n  default_svid_ttl = \"12h\"\n  ca_subject = {\n    country = [\"US\"],\n    organization = [\"SPIFFE\"],\n    common_name = \"\",\n  }\n}\n\nplugins {\n  DataStore \"sql\" {\n    plugin_data {\n      database_type = \"sqlite3\"\n      connection_string = \"/opt/spire/data/datastore.sqlite3\"\n    }\n  }\n\n  NodeAttestor \"k8s_sat\" {\n    plugin_data {\n      clusters = {\n        # NOTE: Change this to your cluster name\n        \"demo-cluster\" = {\n          use_token_review_api_validation = true\n          service_account_whitelist = [\"spire:spire-agent\"]\n        }\n      }\n    }\n  }\n\n  NodeResolver \"noop\" {\n    plugin_data {}\n  }\n\n  KeyManager \"disk\" {\n    plugin_data {\n      keys_path = \"/opt/spire/data/keys.json\"\n    }\n  }\n\n  Notifier \"k8sbundle\" {\n    plugin_data {\n    }\n  }\n}\n\nhealth_checks {\n  listener_enabled = true\n  bind_address = \"0.0.0.0\"\n  bind_port = \"8080\"\n  live_path = \"/live\"\n  ready_path = \"/ready\"\n}\n"
  }
  depends_on = [kubernetes_namespace.spire]
}

resource "kubernetes_service" "spire_server" {
  metadata {
    name      = "spire-server"
    namespace = "spire"
  }

  spec {
    port {
      name        = "grpc"
      protocol    = "TCP"
      port        = 8081
      target_port = "8081"
    }

    selector = {
      app = "spire-server"
    }

    type = "NodePort"
  }
  depends_on = [kubernetes_namespace.spire]
}

resource "kubernetes_stateful_set" "spire_server" {
  metadata {
    name      = "spire-server"
    namespace = "spire"

    labels = {
      app = "spire-server"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "spire-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "spire-server"
        }
      }

      spec {
        volume {
          name = "spire-config"

          config_map {
            name = "spire-server"
          }
        }

        container {
          name  = "spire-server"
          image = "gcr.io/spiffe-io/spire-server:0.12.1"
          args  = ["-config", "/opt/spire/config/server.conf"]

          port {
            container_port = 8081
          }

          volume_mount {
            name       = "spire-config"
            read_only  = true
            mount_path = "/opt/spire/config"
          }

          volume_mount {
            name       = "spire-data"
            mount_path = "/opt/spire/data"
          }

          liveness_probe {
            http_get {
              path = "/live"
              port = "8080"
            }

            initial_delay_seconds = 15
            timeout_seconds       = 3
            period_seconds        = 60
            failure_threshold     = 2
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = "8080"
            }

            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        service_account_name = "spire-server"
        automount_service_account_token = true
      }
    }

    volume_claim_template {
      metadata {
        name      = "spire-data"
        namespace = "spire"
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }

    service_name = "spire-server"
  }
  depends_on = [kubernetes_namespace.spire]
}

