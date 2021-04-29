resource "aws_iam_policy" "oidc-federation-spire-policy" {
  name        = "oidc-federation-spire-policy"
  description = "oidc-federation-spire-policy"

  policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutAccountPublicAccessBlock",
                "s3:GetAccountPublicAccessBlock",
                "s3:ListAllMyBuckets",
                "s3:ListJobs",
                "s3:CreateJob",
                "s3:HeadBucket"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::scytale-oidc",
                "arn:aws:s3:::scytale-oidc/*",
                "arn:aws:s3:*:*:job/*"
            ]
        }
    ]
}
EOT
}