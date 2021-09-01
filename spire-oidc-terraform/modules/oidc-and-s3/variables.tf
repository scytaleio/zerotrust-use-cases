# variables.tf
variable "region" {
}

variable "oidc_role_name" {
  description = "AWS IAM OIDC Federation role name"
  type = string
  default = "scytale-oidc-federation-role"
}

variable "s3_bucket_name" {
  description = "AWS S3 Bucket name"
  type = string
  default = "scytale-oidc"
}

variable "trust_domain" {
  description = "SPIFFE SPIRE Trust Domain"
  type = string
}

