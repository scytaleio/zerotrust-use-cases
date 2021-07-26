
resource "kubernetes_service_account" "spire_agent" {
  metadata {
    name      = "spire-agent"
    namespace = "spire"
  }
  automount_service_account_token = true
}

resource "kubernetes_cluster_role" "spire_agent_cluster_role" {
  metadata {
    name = "spire-agent-cluster-role"
  }

  rule {
    verbs      = ["get"]
    api_groups = [""]
    resources  = ["pods", "nodes", "nodes/proxy"]
  }
}

resource "kubernetes_cluster_role_binding" "spire_agent_cluster_role_binding" {
  metadata {
    name = "spire-agent-cluster-role-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "spire-agent"
    namespace = "spire"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "spire-agent-cluster-role"
  }
}

resource "kubernetes_config_map" "spire_agent" {
  metadata {
    name      = "spire-agent"
    namespace = "spire"
  }

  data = {
    "agent.conf" = "agent {\n  data_dir = \"/opt/spire\"\n  log_level = \"DEBUG\"\n  server_address = \"spire-server\"\n  server_port = \"8081\"\n  socket_path = \"/opt/spire/sockets/agent.sock\"\n  trust_bundle_path = \"/opt/spire/bundle/bundle.crt\"\n  trust_domain = \"envoy.spire-test.com\"\n}\n\nplugins {\n  NodeAttestor \"k8s_sat\" {\n    plugin_data {\n      # NOTE: Change this to your cluster name\n      cluster = \"demo-cluster\"\n    }\n  }\n\n  KeyManager \"memory\" {\n    plugin_data {\n    }\n  }\n\n  WorkloadAttestor \"k8s\" {\n    plugin_data {\n      # Defaults to the secure kubelet port by default.\n      # Minikube does not have a cert in the cluster CA bundle that\n      # can authenticate the kubelet cert, so skip validation.\n      skip_kubelet_verification = true\n    }\n  }\n\n  WorkloadAttestor \"unix\" {\n      plugin_data {\n      }\n  }\n}\n\nhealth_checks {\n  listener_enabled = true\n  bind_address = \"0.0.0.0\"\n  bind_port = \"8080\"\n  live_path = \"/live\"\n  ready_path = \"/ready\"\n}\n"
  }
}

resource "kubernetes_daemonset" "spire_agent" {
  metadata {
    name      = "spire-agent"
    namespace = "spire"

    labels = {
      app = "spire-agent"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "spire-agent"
      }
    }

    template {
      metadata {
        labels = {
          app = "spire-agent"
        }
      }

      spec {
        volume {
          name = "spire-config"

          config_map {
            name = "spire-agent"
          }
        }

        volume {
          name = "spire-bundle"

          config_map {
            name = "spire-bundle"
          }
        }

        volume {
          name = "spire-agent-socket"

          host_path {
            path = "/opt/spire/sockets"
            type = "DirectoryOrCreate"
          }
        }

        init_container {
          name  = "init"
          image = "gcr.io/spiffe-io/wait-for-it"
          args  = ["-t", "30", "spire-server:8081"]
        }

        container {
          name  = "spire-agent"
          image = "gcr.io/spiffe-io/spire-agent:0.12.1"
          args  = ["-config", "/opt/spire/config/agent.conf"]

          volume_mount {
            name       = "spire-config"
            read_only  = true
            mount_path = "/opt/spire/config"
          }

          volume_mount {
            name       = "spire-bundle"
            mount_path = "/opt/spire/bundle"
          }

          volume_mount {
            name       = "spire-agent-socket"
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

        dns_policy           = "ClusterFirstWithHostNet"
        service_account_name = "spire-agent"
        automount_service_account_token = true
        host_network         = true
        host_pid             = true
      }
    }
  }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [kubernetes_daemonset.spire_agent]

  create_duration = "30s"
}

resource "null_resource" "spire_node_registration" {
  depends_on = [time_sleep.wait_30_seconds]
  provisioner "local-exec" {
    command = <<EOT
kubectl exec -n spire spire-server-0 -- /opt/spire/bin/spire-server entry create -spiffeID spiffe://envoy.spire-test.com/ns/spire/sa/spire-agent -selector k8s_sat:cluster:demo-cluster -selector k8s_sat:agent_ns:spire -selector k8s_sat:agent_sa:spire-agent -node
EOT
  }
}

resource "null_resource" "spire_agent_registration" {
  depends_on = [time_sleep.wait_30_seconds]
  provisioner "local-exec" {
    command = <<EOT
kubectl exec -n spire spire-server-0 -- /opt/spire/bin/spire-server entry create -spiffeID spiffe://envoy.spire-test.com/ns/default/sa/default -parentID spiffe://envoy.spire-test.com/ns/spire/sa/spire-agent -selector k8s:ns:default -selector k8s:sa:default
EOT
  }
}
