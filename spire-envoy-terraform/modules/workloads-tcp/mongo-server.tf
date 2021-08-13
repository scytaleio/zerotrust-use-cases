
resource "kubernetes_storage_class" "spire_gp_2" {
  metadata {
    name = "spire-gp2"
  }

  storage_provisioner = "kubernetes.io/aws-ebs"

  parameters = {
      type = "gp2"
      fsType = "ext4"
  }

}

resource "kubernetes_persistent_volume_claim" "spire_mongo_pvc" {
  metadata {
    name = "spire-mongo-pvc"
    namespace = "spire"

    annotations = {
      "volume.beta.kubernetes.io/storage-class" = "spire-gp2"
    }
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
}

resource "kubernetes_service" "mongo_envoy" {
  metadata {
    name = "mongo-envoy"
    namespace = "spire"
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 10100
      target_port = "10100"
    }

    selector = {
      app = "mongo"
    }
  }
}

resource "kubernetes_config_map" "mongo_envoy" {
  metadata {
    name      = "mongo-envoy"
    namespace = "spire"
  }

  data = {
    "envoy.yaml" = "node:\n  id: \"mongo-backend\"\n  cluster: \"demo-tcpcluster-spire\"\nstatic_resources:\n  listeners:\n  - address:\n      socket_address:\n        address: 0.0.0.0\n        port_value: 10100\n    filter_chains:\n    - filters:\n      - name: envoy.filters.network.mongo_proxy\n        typed_config:\n          \"@type\": type.googleapis.com/envoy.extensions.filters.network.mongo_proxy.v3.MongoProxy\n          stat_prefix: mongo\n      - name: envoy.filters.network.tcp_proxy\n        typed_config:\n          \"@type\": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy\n          stat_prefix: tcp\n          cluster: local_service\n      transport_socket:\n        name: envoy.transport_sockets.tls\n        typed_config:\n          \"@type\": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext\n          common_tls_context:\n            tls_certificate_sds_secret_configs:\n            - name: \"spiffe://${var.trust_domain}/ns/spire/sa/default/mongo-backend\"\n              sds_config:\n                api_config_source:\n                  api_type: GRPC\n                  grpc_services:\n                    envoy_grpc:\n                      cluster_name: spire_agent\n                  transport_api_version: V3\n                resource_api_version: V3\n            combined_validation_context:\n              default_validation_context:\n                match_subject_alt_names:\n                  exact: \"spiffe://${var.trust_domain}/ns/spire/sa/default/mongo-client\"\n              validation_context_sds_secret_config:\n                name: \"spiffe://${var.trust_domain}\"\n                sds_config:\n                  api_config_source:\n                    api_type: GRPC\n                    grpc_services:\n                      envoy_grpc:\n                        cluster_name: spire_agent\n                    transport_api_version: V3\n                  resource_api_version: V3\n            tls_params:\n               ecdh_curves:\n                - X25519:P-256:P-521:P-384\n  clusters:\n  - name: spire_agent\n    connect_timeout: 1s\n    typed_extension_protocol_options:\n      envoy.extensions.upstreams.http.v3.HttpProtocolOptions:\n        \"@type\": type.googleapis.com/envoy.extensions.upstreams.http.v3.HttpProtocolOptions\n        explicit_http_config:\n          http2_protocol_options: {}\n    load_assignment:  \n      cluster_name: spire_agent\n      endpoints:  \n      - lb_endpoints: \n        - endpoint: \n            address:  \n              pipe: \n                path: /opt/spire/sockets/agent.sock\n  - name: local_service\n    connect_timeout: 1s\n    type: STRICT_DNS\n    lb_policy: ROUND_ROBIN\n    load_assignment:\n      cluster_name: local_service\n      endpoints:\n      - lb_endpoints:\n        - endpoint:\n            address:\n              socket_address:\n                address: 127.0.0.1\n                port_value: 27017\n"
  }
}

resource "kubernetes_deployment" "mongo" {
  metadata {
    name = "mongo"
    namespace = "spire"

    labels = {
      app = "mongo"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "mongo"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongo"
        }
      }

      spec {
        volume {
          name = "envoy-config"

          config_map {
            name = "mongo-envoy"
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
          name = "mongodb"

          persistent_volume_claim {
            claim_name = "spire-mongo-pvc"
          }
        }

        container {
          name  = "envoy"
          image = "envoyproxy/envoy-alpine:v1.18.2"
          args  = ["-l", "debug", "--local-address-ip-version", "v4", "-c", "/opt/envoy/envoy.yaml"]

          port {
            container_port = 10100
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
          name  = "mongo"
          image = "mongo"

          port {
            container_port = 27017
          }

          volume_mount {
            name       = "mongodb"
            mount_path = "/data/db"
          }
        }
      }
    }
  }
}

