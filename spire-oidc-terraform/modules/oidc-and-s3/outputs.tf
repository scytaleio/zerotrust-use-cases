output "oidc_provider_arn" {
  description = "OIDC ARN"
  value = aws_iam_openid_connect_provider.scytale-oidc.arn
}

output "oidc_role_arn" {
  description = "OIDC Role ARN"
  value = aws_iam_role.oidc_role.arn
}

output "s3_bucket_name" {
  description = "AWS S3 Bucket Name"
  value = var.s3_bucket_name
}

