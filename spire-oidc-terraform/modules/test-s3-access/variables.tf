variable "kubeconfig" {
  description = "Kubeconfig path"
  type = string
}

variable "trust_domain" {
  description = "SPIFFE SPIRE Trust Domain"
  type = string
}

variable "oidc_provider_arn" {
  description = "OIDC Provider ARN"
  type = string
}

variable "oidc_role_arn" {
  description = "OIDC Provider Role ARN"
  type = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type = string
}

