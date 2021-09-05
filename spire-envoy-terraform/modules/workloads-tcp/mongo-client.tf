
resource "kubernetes_service" "mongo_client" {
  metadata {
    name = "mongo-client"
    namespace = "spire"
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 27017
      target_port = "10000"
    }

    selector = {
      app = "client"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "client_envoy" {
  metadata {
    name      = "client-envoy"
    namespace = "spire"
  }

  data = {
    "envoy.yaml" = "node:\n  id: \"mongo-client\"\n  cluster: \"demo-tcpcluster-spire\"\nstatic_resources:\n  listeners:\n  - address:\n      socket_address:\n        address: 0.0.0.0\n        port_value: 10000\n    filter_chains:\n    - filters:\n      - name: envoy.filters.network.tcp_proxy\n        typed_config:\n          \"@type\": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy\n          stat_prefix: tcp\n          cluster: mongo-backend\n  clusters:\n  - name: spire_agent\n    connect_timeout: 1s\n    typed_extension_protocol_options:\n        envoy.extensions.upstreams.http.v3.HttpProtocolOptions:\n          \"@type\": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions\n          explicit_http_config:\n            http2_protocol_options: {}\n    load_assignment:  \n      cluster_name: spire_agent\n      endpoints:  \n      - lb_endpoints: \n        - endpoint: \n            address:  \n              pipe: \n                path: /opt/spire/sockets/agent.sock\n  - name: mongo-backend\n    connect_timeout: 1s\n    type: STRICT_DNS\n    lb_policy: ROUND_ROBIN\n    load_assignment:\n      cluster_name: mongo-backend\n      endpoints:\n      - lb_endpoints:\n        - endpoint:\n            address:\n              socket_address:\n                address: mongo-envoy\n                port_value: 10100\n    transport_socket:\n      name: envoy.transport_sockets.tls\n      typed_config:\n        \"@type\": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext\n        common_tls_context:\n          tls_certificate_sds_secret_configs:\n            - name: \"spiffe://${var.trust_domain}/ns/spire/sa/default/mongo-client\"\n              sds_config:\n                api_config_source:\n                  api_type: GRPC\n                  grpc_services:\n                    envoy_grpc:\n                      cluster_name: spire_agent\n                  transport_api_version: V3\n                resource_api_version: V3\n          combined_validation_context:\n            default_validation_context:\n              match_subject_alt_names:\n                exact: \"spiffe://${var.trust_domain}/ns/spire/sa/default/mongo-backend\"\n            validation_context_sds_secret_config:\n              name: \"spiffe://${var.trust_domain}\"\n              sds_config:\n                api_config_source:\n                  api_type: GRPC\n                  grpc_services:\n                    envoy_grpc:\n                      cluster_name: spire_agent\n                  transport_api_version: V3\n                resource_api_version: V3\n          tls_params:\n            ecdh_curves:\n              - X25519:P-256:P-521:P-384\n"
  }
}


resource "kubernetes_deployment" "client" {
  metadata {
    name = "client"
    namespace = "spire"

    labels = {
      app = "client"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "client"
      }
    }

    template {
      metadata {
        labels = {
          app = "client"
        }
      }

      spec {
        volume {
          name = "envoy-config"

          config_map {
            name = "client-envoy"
          }
        }

        volume {
          name = "spire-agent-socket"

          host_path {
            path = "/opt/spire/sockets"
            type = "DirectoryOrCreate"
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
          name  = "mongo-client"
          image = "mongoclient/mongoclient"

          port {
            container_port = 3000
          }

          image_pull_policy = "IfNotPresent"
        }
      }
    }
  }
}

