
resource "kubernetes_service" "backend_envoy" {
  metadata {
    name = "backend-envoy"
    namespace = "spire"
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 9001
      target_port = "9001"
    }

    selector = {
      app = "backend"
    }

    cluster_ip = "None"
  }
}

resource "kubernetes_config_map" "backend_balance_json_data" {
  metadata {
    name      = "backend-balance-json-data"
    namespace = "spire"
  }

  data = {
    balance_1 = "{\n  \"balance\": 10.95\n}"

    balance_2 = "{\n  \"balance\": 310\n}"
  }
}

resource "kubernetes_config_map" "backend_envoy" {
  metadata {
    name      = "backend-envoy"
    namespace = "spire"
  }

  data = {
    "envoy.yaml" = "node:\n  id: \"backend\"\n  cluster: \"demo-cluster-spire\"\nstatic_resources:\n  listeners:\n  - address:\n      socket_address:\n        address: 0.0.0.0\n        port_value: 9001\n    filter_chains:\n    - filters:\n      - name: envoy.filters.network.http_connection_manager\n        typed_config:\n          \"@type\": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager\n          codec_type: AUTO\n          stat_prefix: ingress_http\n          route_config:\n            name: local_route\n            virtual_hosts:\n            - name: service\n              domains:\n              - \"*\"\n              routes:\n              - match:\n                  prefix: \"/\"\n                route:\n                  cluster: local_service\n          http_filters:\n          - name: envoy.filters.http.router\n      transport_socket:\n        name: envoy.transport_sockets.tls\n        typed_config:\n          \"@type\": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext\n          common_tls_context:\n            tls_certificate_sds_secret_configs:\n            - name: \"spiffe://${var.trust_domain}/ns/spire/sa/default/backend\"\n              sds_config:\n                api_config_source:\n                  api_type: GRPC\n                  grpc_services:\n                    envoy_grpc:\n                      cluster_name: spire_agent\n                  transport_api_version: V3\n                resource_api_version: V3\n            combined_validation_context:\n              # validate the SPIFFE ID of incoming clients (optionally)\n              default_validation_context:\n                match_subject_alt_names:\n                  exact: \"spiffe://${var.trust_domain}/ns/spire/sa/default/frontend\"\n              # obtain the trust bundle from SDS\n              validation_context_sds_secret_config:\n                name: \"spiffe://${var.trust_domain}\"\n                sds_config:\n                  api_config_source:\n                    api_type: GRPC\n                    grpc_services:\n                      envoy_grpc:\n                        cluster_name: spire_agent\n                    transport_api_version: V3\n                  resource_api_version: V3\n            tls_params:\n              ecdh_curves:\n                - X25519:P-256:P-521:P-384\n  clusters:\n  - name: spire_agent\n    connect_timeout: 0.25s\n    http2_protocol_options: {}\n    load_assignment:  \n      cluster_name: spire_agent\n      endpoints:  \n      - lb_endpoints: \n        - endpoint: \n            address:  \n              pipe: \n                path: /opt/spire/sockets/agent.sock\n  - name: local_service\n    connect_timeout: 1s\n    type: STRICT_DNS\n    lb_policy: ROUND_ROBIN\n    load_assignment:\n      cluster_name: local_service\n      endpoints:\n      - lb_endpoints:\n        - endpoint:\n            address:\n              socket_address:\n                address: 127.0.0.1\n                port_value: 80\n"
  }
}

resource "kubernetes_config_map" "backend_profile_json_data" {
  metadata {
    name      = "backend-profile-json-data"
    namespace = "spire"
  }

  data = {
    profile_1 = "{\n  \"Name\": \"Jacob Marley\",\n  \"Address\": \"48-49 Doughty ST, Holborn - London WC1N 2LX.UK\"\n}"
    profile_2 = "{\n  \"Name\": \"Alex Fergus\",\n  \"Address\": \"Sir Matt Busby Way, Trafford Park, Stretford, Manchester M16 0RA, Reino Unido\"\n}"
  }
}

resource "kubernetes_config_map" "backend_transactions_json_data" {
  metadata {
    name      = "backend-transactions-json-data"
    namespace = "spire"
  }

  data = {
    transaction_1 = "{\n  \"transactions\": [\n    {\n      \"description\": \"Kohls: Crhistmas decorations\",\n      \"debit\": 20\n    },\n    {\n      \"description\": \"Alms from the collections\",\n      \"credit\": 450\n    },\n    {\n      \"description\": \"Khols: Christmas cards\",\n      \"debit\": 20\n    },\n    {\n      \"description\": \"Cash withdrawl\",\n      \"debit\": 600\n    },\n    {\n      \"description\": \"Pay from employer\",\n      \"credit\": 6000\n    },\n    {\n      \"description\": \"Health Insurance: Tiny Tim\",\n      \"debit\": 5000\n    },\n    {\n      \"description\": \"Opening Balance\",\n      \"debit\": 10000\n    }\n\n  ]\n}\n"

    transaction_2 = "{\n  \"transactions\": [\n    {\n      \"description\": \"Kohls: Crhistmas decorations\",\n      \"debit\": 20\n    },\n    {\n      \"description\": \"Alms from the collections\",\n      \"credit\": 450\n    },\n    {\n      \"description\": \"Khols: Christmas cards\",\n      \"debit\": 20\n    },\n    {\n      \"description\": \"Cash withdrawl\",\n      \"debit\": 300\n    },\n    {\n      \"description\": \"Pay from employer\",\n      \"credit\": 600\n    },\n    {\n      \"description\": \"Health Insurance: Tiny Tim\",\n      \"debit\": 500\n    },\n    {\n      \"description\": \"Opening Balance\",\n      \"debit\": 1000\n    }\n\n  ]\n}\n"
  }
}

resource "kubernetes_deployment" "backend" {
  metadata {
    name = "backend"
    namespace = "spire"

    labels = {
      app = "backend"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        volume {
          name = "envoy-config"

          config_map {
            name = "backend-envoy"
          }
        }

        volume {
          name = "spire-agent-socket"

          host_path {
            path = "/opt/spire/sockets"
            type = "Directory"
          }
        }

        volume {
          name = "backend-balance-json-data"

          config_map {
            name = "backend-balance-json-data"
          }
        }

        volume {
          name = "backend-profile-json-data"

          config_map {
            name = "backend-profile-json-data"
          }
        }

        volume {
          name = "backend-transactions-json-data"

          config_map {
            name = "backend-transactions-json-data"
          }
        }

        container {
          name  = "envoy"
          image = "envoyproxy/envoy-alpine:v1.18.2"
          args  = ["-l", "debug", "--local-address-ip-version", "v4", "-c", "/opt/envoy/envoy.yaml"]

          port {
            container_port = 9001
          }

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
          name  = "backend"
          image = "nginx"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "backend-balance-json-data"
            read_only  = true
            mount_path = "/usr/share/nginx/html/balances"
          }

          volume_mount {
            name       = "backend-profile-json-data"
            read_only  = true
            mount_path = "/usr/share/nginx/html/profiles"
          }

          volume_mount {
            name       = "backend-transactions-json-data"
            read_only  = true
            mount_path = "/usr/share/nginx/html/transactions"
          }
        }
      }
    }
  }
}

