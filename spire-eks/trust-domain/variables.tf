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

variable "elb" {
  description = "OIDC LB"
  type = string
}

variable "elbname" {
  description = "OIDC LB Name"
  type = string
}

variable "kubeconfig" {
  description = "Kubeconfig path"
  type = string
}

variable "acm_certificate_arn" {
  description = "ACM Certificate ARN"
  type = string
}

