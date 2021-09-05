variable "trust_domain" {
  description = "SPIFFE SPIRE Trust Domain"
  type = string
}

variable "kubeconfig" {
  description = "Kubeconfig path"
  type = string
}

variable "email" {
  description = "Email for ACME"
  type = string
  default = "test@example.com"
}

variable "acm_certificate_arn" {
  description = "ACM Certificate ARN"
  type = string
}

