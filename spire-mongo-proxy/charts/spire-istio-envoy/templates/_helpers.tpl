{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "envoy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "envoy.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "envoy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "envoy_yaml.frontend_listener" -}}
# frontend listener template
- name: envoy.http_connection_manager
  typed_config:
    "@type": type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager
    common_http_protocol_options:
      idle_timeout: 1s
    codec_type: auto
    access_log:
    - name: envoy.file_access_log
      config:
        path: "/dev/stdout"
    stat_prefix: ingress_http
    route_config:
      name: service_route
      virtual_hosts:
      - name: outbound_proxy
        domains: ["*"]
        routes:
        - match:
            prefix: "/"
          route:
            cluster: upstream
    http_filters:
    - name: envoy.router
{{- end -}}

{{- define "envoy_yaml.backend_listener" -}}
# backend listener template
- name: envoy.http_connection_manager
  typed_config:
    "@type": type.googleapis.com/envoy.config.filter.network.http_connection_manager.v2.HttpConnectionManager
    common_http_protocol_options:
      idle_timeout: 1s
    forward_client_cert_details: sanitize_set
    set_current_client_cert_details:
      uri: true
    codec_type: auto
    access_log:
    - name: envoy.file_access_log
      config:
        path: "/dev/stdout"
    stat_prefix: ingress_http
    route_config:
      name: local_route
      virtual_hosts:
      - name: local_service
        domains: ["*"]
        routes:
        - match:
            prefix: "/"
          route:
            cluster: upstream
    http_filters:
    - name: envoy.router
tls_context:
  common_tls_context:
    require_client_certificate: true
    tls_certificate_sds_secret_configs:
    - name: "{{ .Values.backendSpiffeId }}"
      sds_config:
        api_config_source:
          api_type: GRPC
          grpc_services:
            envoy_grpc:
              cluster_name: spire_agent
    combined_validation_context:
      # validate the SPIFFE ID of incoming clients (optionally)
      default_validation_context:
        match_subject_alt_names:
        - exact: "{{ .Values.frontendSpiffeId }}"
      validation_context_sds_secret_config:
        name: "{{ .Values.trustDomain }}"
        sds_config:
          api_config_source:
            api_type: GRPC
            grpc_services:
              envoy_grpc:
                cluster_name: spire_agent
    tls_params:
      ecdh_curves:
      - X25519:P-256:P-521:P-384
{{- end -}}

{{- define "envoy_yaml.frontend_cluster" -}}
# frontend cluster
  - name: upstream
    connect_timeout: 0.25s
    type: strict_dns
    lb_policy: ROUND_ROBIN
    hosts:
    - socket_address:
        address: {{ .Values.upstreamHost }}
        port_value: {{ .Values.upstreamPort }}
    tls_context:
      common_tls_context:
        tls_certificate_sds_secret_configs:
        - name: {{ .Values.frontendSpiffeId }}
          sds_config:
            api_config_source:
              api_type: GRPC
              grpc_services:
                envoy_grpc:
                  cluster_name: spire_agent
    combined_validation_context:
      # validate the SPIFFE ID of the server (recommended)
      validation_context:
        match_subject_alt_names:
          exact: {{ .Values.backendSpiffeId }}
      validation_context_sds_secret_config:
        name: spiffe_validation_context
        sds_config:
          api_config_source:
            api_type: GRPC
            grpc_services:
              envoy_grpc:
                cluster_name: spire_agent
    tls_params:
      ecdh_curves:
      - X25519:P-256:P-521:P-384
{{- end -}}


{{- define "envoy_yaml.backend_cluster" -}}
# backend cluster
  - name: upstream
    connect_timeout: 1s
    type: strict_dns
    hosts:
      - socket_address:
          address: {{ .Values.upstreamHost }}
          port_value: {{ .Values.upstreamPort }}
{{- end -}}