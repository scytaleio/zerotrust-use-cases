# variables.tf
variable "region" {
}

variable "trust_domain" {
  description = "SPIFFE SPIRE Trust Domain"
  type = string
}

variable "dnsZone" {
    default = "spire-test.com"
}

variable "kubeconfig" {
  description = "Kubeconfig path"
  type = string
}

