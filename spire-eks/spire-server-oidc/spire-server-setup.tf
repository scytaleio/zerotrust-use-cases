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
    "server.conf" = "server {\n  bind_address = \"0.0.0.0\"\n  bind_port = \"8081\"\n  socket_path = \"/tmp/spire-server/private/api.sock\"\n  trust_domain = \"${var.trust_domain}\"\n  data_dir = \"/opt/spire/data\"\n  log_level = \"DEBUG\"\n  experimental {\n    // Turns on the bundle endpoint (required, true)\n    bundle_endpoint_enabled = true\n\n    // The address to listen on (optional, defaults to 0.0.0.0)\n    // bundle_endpoint_address = \"0.0.0.0\"\n\n    // The port to listen on (optional, defaults to 443)\n    bundle_endpoint_port = 8443\n  }\n  ca_key_type = \"rsa-2048\"\n\n  # Creates the iss claim in JWT-SVIDs.\n  # TODO: Replace MY_DISCOVERY_DOMAIN with the FQDN of the Discovery Provider that you will configure in DNS\n  jwt_issuer = \"${var.trust_domain}\"\n\n  default_svid_ttl = \"1h\"\n  ca_subject = {\n    country = [\"US\"],\n    organization = [\"SPIFFE\"],\n    common_name = \"\",\n  }\n}\n\nplugins {\n  DataStore \"sql\" {\n    plugin_data {\n      database_type = \"sqlite3\"\n      connection_string = \"/opt/spire/data/datastore.sqlite3\"\n    }\n  }\n\n  NodeAttestor \"k8s_sat\" {\n    plugin_data {\n      clusters = {\n        # TODO: Change this to your cluster name\n        \"demo-cluster\" = {\n          use_token_review_api_validation = true\n          service_account_whitelist = [\"spire:spire-agent\"]\n        }\n      }\n    }\n  }\n\n  NodeResolver \"noop\" {\n    plugin_data {}\n  }\n\n  KeyManager \"disk\" {\n    plugin_data {\n      keys_path = \"/opt/spire/data/keys.json\"\n    }\n  }\n\n  Notifier \"k8sbundle\" {\n    plugin_data {\n    }\n  }\n}\n\nhealth_checks {\n  listener_enabled = true\n  bind_address = \"0.0.0.0\"\n  bind_port = \"8080\"\n  live_path = \"/live\"\n  ready_path = \"/ready\"\n}\n"
  }
  depends_on = [kubernetes_namespace.spire]
}

resource "kubernetes_config_map" "oidc_discovery_provider" {
  metadata {
    name      = "oidc-discovery-provider"
    namespace = "spire"
  }

  data = {
    "oidc-discovery-provider.conf" = "log_level = \"INFO\"\n# TODO: Replace MY_DISCOVERY_DOMAIN with the FQDN of the Discovery Provider that you will configure in DNS\ndomain = \"${var.trust_domain}\"\ninsecure_addr = \":8082\"\n#acme {\n#    directory_url = \"https://acme-v02.api.letsencrypt.org/directory\"\n#    cache_dir = \"/opt/spire\"\n#    tos_accepted = true\n#    # TODO: Change MY_EMAIL_ADDRESS with your email\n#    email = \"${var.email}\"\n#}\nregistration_api {\n    socket_path = \"/tmp/spire-server/private/api.sock\"\n}\n"
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

resource "kubernetes_service" "spire_oidc" {
  metadata {
    name      = "spire-oidc"
    namespace = "spire"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
      "service.beta.kubernetes.io/aws-load-balancer-ssl-cert" = "${var.acm_certificate_arn}"
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "https"
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol" = "*"
      "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout" = "3600"
      "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
      "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "443"
      "service.beta.kubernetes.io/aws-load-balancer-internal" = "false"
    }
  }

  spec {
    port {
      name        = "http"
      port        = 443
      target_port = "8082"
    }

    selector = {
      app = "spire-server"
    }

    type = "LoadBalancer"
  }
  depends_on = [kubernetes_namespace.spire]
}

resource "kubernetes_ingress" "spire_ingress" {
  metadata {
    name      = "spire-ingress"
    namespace = "spire"
  }

  spec {
    tls {
      hosts       = ["${var.trust_domain}"]
      secret_name = "oidc-secret"
    }

    rule {
      host = "${var.trust_domain}"

      http {
        path {
          path = "/.well-known/openid-configuration"

          backend {
            service_name = "spire-oidc"
            service_port = "443"
          }
        }

        path {
          path = "/keys"

          backend {
            service_name = "spire-oidc"
            service_port = "443"
          }
        }
      }
    }
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

        volume {
          name = "spire-server-socket"

          host_path {
            path = "/opt/spire/sockets/server"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "spire-oidc-config"

          config_map {
            name = "oidc-discovery-provider"
          }
        }

        container {
          name  = "spire-server"
          image = "gcr.io/spiffe-io/spire-server:1.0.0"
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

          volume_mount {
            name       = "spire-server-socket"
            mount_path = "/opt/spire/sockets"
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

        container {
          name  = "spire-oidc"
          image = "gcr.io/spiffe-io/oidc-discovery-provider:1.0.0"
          args  = ["-config", "/opt/spire/oidc/config/oidc-discovery-provider.conf"]

          port {
            name           = "spire-oidc-port"
            container_port = 8082
          }

          volume_mount {
            name       = "spire-server-socket"
            read_only  = true
            mount_path = "/opt/spire/sockets"
          }

          volume_mount {
            name       = "spire-oidc-config"
            read_only  = true
            mount_path = "/opt/spire/oidc/config/"
          }

          volume_mount {
            name       = "spire-data"
            mount_path = "/opt/spire/data"
          }

          readiness_probe {
            exec {
              command = ["/bin/ps", "aux", " ||", "grep", "oidc-discovery-provider -config /opt/spire/oidc/config/oidc-discovery-provider.conf"]
            }

            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        service_account_name    = "spire-server"
        automount_service_account_token = true
        share_process_namespace = true
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

resource "time_sleep" "wait_for_lb" {
  create_duration = "60s"
  depends_on = [kubernetes_service.spire_oidc]
}

data "external" "get_spire_oidc_lb" {
  program = ["bash", "-c", <<EOT
export KUBECONFIG="${var.kubeconfig}"
elb="`kubectl get services -n spire spire-oidc --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'`"
elbName=`echo $elb | cut -d'-' -f 1`
echo "{\"elb\": \"$elb\", \"elbName\": \"$elbName\"}"
EOT
]
  depends_on = [time_sleep.wait_for_lb]
}

resource "null_resource" "print_lb" {
  depends_on = [data.external.get_spire_oidc_lb]
  provisioner "local-exec" {
    command = <<EOT
echo Spire OIDC LB is ${data.external.get_spire_oidc_lb.result.elb}
echo Spire OIDC LBName ${data.external.get_spire_oidc_lb.result.elbName}
EOT
  }
}

