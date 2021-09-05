
resource "kubernetes_service" "frontend" {
  metadata {
    name = "frontend"
    namespace = "spire"
  }

  spec {
    port {
      name        = "http"
      protocol    = "TCP"
      port        = 3000
      target_port = "3000"
    }

    selector = {
      app = "frontend"
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_config_map" "frontend_envoy" {
  metadata {
    name      = "frontend-envoy"
    namespace = "spire"
  }

  data = {
    "envoy.yaml" = "node:\n  id: \"frontend\"\n  cluster: \"demo-cluster-spire\"\nstatic_resources:\n  listeners:\n  - address:\n      socket_address:\n        address: 0.0.0.0\n        port_value: 3001\n    filter_chains:\n    - filters:\n      - name: envoy.filters.network.http_connection_manager\n        typed_config:\n          \"@type\": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager\n          codec_type: AUTO\n          stat_prefix: ingress_http\n          route_config:\n            name: local_route\n            virtual_hosts:\n            - name: outbound_proxy\n              domains:\n              - \"*\"\n              routes:\n              - match:\n                  prefix: \"/\"\n                route:\n                  cluster: backend\n          http_filters:\n          - name: envoy.filters.http.router\n\n  clusters:\n  - name: spire_agent\n    connect_timeout: 0.25s\n    http2_protocol_options: {}\n    load_assignment:  \n      cluster_name: spire_agent\n      endpoints:  \n      - lb_endpoints: \n        - endpoint: \n            address:  \n              pipe: \n                path: /opt/spire/sockets/agent.sock\n  - name: backend\n    connect_timeout: 1s\n    type: STRICT_DNS\n    lb_policy: ROUND_ROBIN\n    load_assignment:\n      cluster_name: backend\n      endpoints:\n      - lb_endpoints:\n        - endpoint:\n            address:\n              socket_address:\n                address: backend-envoy\n                port_value: 9001\n    transport_socket:\n      name: envoy.transport_sockets.tls\n      typed_config:\n        \"@type\": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext\n        common_tls_context:\n          tls_certificate_sds_secret_configs:\n            - name: \"spiffe://${var.trust_domain}/ns/spire/sa/default/frontend\"\n              sds_config:\n                api_config_source:\n                  api_type: GRPC\n                  grpc_services:\n                    envoy_grpc:\n                      cluster_name: spire_agent\n                  transport_api_version: V3\n                resource_api_version: V3\n          combined_validation_context:\n            # validate the SPIFFE ID of the server (recommended)\n            default_validation_context:\n              match_subject_alt_names:\n                exact: \"spiffe://${var.trust_domain}/ns/spire/sa/default/backend\"\n            validation_context_sds_secret_config:\n              name: \"spiffe://${var.trust_domain}\"\n              sds_config:\n                api_config_source:\n                  api_type: GRPC\n                  grpc_services:\n                    envoy_grpc:\n                      cluster_name: spire_agent\n                  transport_api_version: V3\n                resource_api_version: V3\n          tls_params:\n            ecdh_curves:\n              - X25519:P-256:P-521:P-384\nadmin:\n  address:\n    socket_address:\n      address: 0.0.0.0\n      port_value: 8001\n"
  }
}

resource "kubernetes_config_map" "symbank_webapp_config" {
  metadata {
    name      = "symbank-webapp-config"
    namespace = "spire"
  }

  data = {
    "symbank-webapp.conf" = "port = 3000\naddress = \"\"\nbalanceDataPath = \"http://localhost:3001/balances/balance_1\"\nprofileDataPath = \"http://localhost:3001/profiles/profile_1\"\ntransactionDataPath = \"http://localhost:3001/transactions/transaction_1\"\n"
  }
}

resource "kubernetes_deployment" "frontend" {
  metadata {
    name = "frontend"
    namespace = "spire"

    labels = {
      app = "frontend"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        volume {
          name = "envoy-config"

          config_map {
            name = "frontend-envoy"
          }
        }

        volume {
          name = "spire-agent-socket"

          host_path {
            path = "/opt/spire/sockets"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "symbank-webapp-config"

          config_map {
            name = "symbank-webapp-config"
          }
        }

        container {
          name  = "envoy"
          image = "envoyproxy/envoy-alpine:v1.18.2"
          args  = ["-l", "debug", "--local-address-ip-version", "v4", "-c", "/opt/envoy/envoy.yaml", "--base-id", "1"]

          volume_mount {
            name       = "envoy-config"
            read_only  = true
            mount_path = "/opt/envoy"
          }

          volume_mount {
            name       = "spire-agent-socket"
            read_only  = true
            mount_path = "/opt/spire/sockets"
          }

          image_pull_policy = "Always"
        }

        container {
          name    = "frontend"
          image   = "us.gcr.io/scytale-registry/symbank-webapp@sha256:a1c9b1d14e14bd1a4e75698a4f153680d2a08e6f8d1f2d7110bff63d39228a75"
          command = ["/opt/symbank-webapp/symbank-webapp", "-config", "/opt/symbank-webapp/config/symbank-webapp.conf"]

          port {
            container_port = 3000
          }

          volume_mount {
            name       = "symbank-webapp-config"
            mount_path = "/opt/symbank-webapp/config"
          }

          image_pull_policy = "IfNotPresent"
        }
      }
    }
  }
}
