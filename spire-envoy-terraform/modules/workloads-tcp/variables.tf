variable "kubeconfig" {
  description = "Kubeconfig path"
  type = string
}

variable "trust_domain" {
  description = "SPIFFE SPIRE Trust Domain"
  type = string
  default = "envoy.spire-test.com"
}

