apiVersion: v1
kind: ConfigMap
metadata:
  name: spire-agent
  namespace: {{ .Values.namespace }}
data:
  agent.conf: |
    agent {
      data_dir = "/run/spire"
      log_level = "DEBUG"
      server_address = "{{ .Values.spireServerAddress }}"
      server_port = "{{ .Values.spireServerPort }}"
      socket_path = "/run/spire/sockets/agent.sock"
      insecure_bootstrap = true
      trust_domain = "{{ .Values.trustdomain }}"
    }
    plugins {
      NodeAttestor "join_token" {
        plugin_data {
        }
      }
      KeyManager "memory" {
        plugin_data {
        }
      }
      WorkloadAttestor "k8s" {
        plugin_data {
          {{- if .Values.azure }}
          kubelet_read_only_port = 10255
          {{- else }}
          skip_kubelet_verification = true
          {{- end }}
        }
      }
    }
