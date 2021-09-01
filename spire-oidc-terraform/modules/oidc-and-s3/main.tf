// Create S3 bucket and upload test.txt file
resource "aws_s3_bucket" "scytale-bucket" {
  bucket = "${var.s3_bucket_name}"
  acl    = "private"
  //region = "${var.region}"

  tags = {
    Name        = "scytale-oidc"
  }
}

resource "aws_s3_bucket_object" "scytale_object" {
  key                    = "scytale_object"
  bucket                 = aws_s3_bucket.scytale-bucket.id
  source                 = "${path.module}/files/test.txt"
  server_side_encryption = "AES256"
  depends_on = [aws_s3_bucket.scytale-bucket]
}

// OIDC Provider
data "tls_certificate" "scytale-oidc" {
  url = "https://${var.trust_domain}"
}


resource "aws_iam_openid_connect_provider" "scytale-oidc" {
  url = "https://${var.trust_domain}"
  client_id_list = ["mys3",]
  thumbprint_list = [data.tls_certificate.scytale-oidc.certificates.0.sha1_fingerprint]
  depends_on = [data.tls_certificate.scytale-oidc]
}

resource "null_resource" "thumb-print" {
  provisioner "local-exec" {
    command = <<EOT
echo ${data.tls_certificate.scytale-oidc.certificates.0.sha1_fingerprint}
EOT
  }
  depends_on = [data.tls_certificate.scytale-oidc]
}

// IAM policy which governs access to s3 bucket
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
                "arn:aws:s3:::${var.s3_bucket_name}",
                "arn:aws:s3:::${var.s3_bucket_name}/*",
                "arn:aws:s3:*:*:job/*"
            ]
        }
    ]
}
EOT
}

// OIDC Role
resource "aws_iam_role" "oidc_role" {
  name = "${var.oidc_role_name}"
  assume_role_policy =  templatefile("${path.module}/files/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.scytale-oidc.arn, OIDC_URL = replace(aws_iam_openid_connect_provider.scytale-oidc.url, "https://", "") })
  depends_on = [aws_iam_policy.oidc-federation-spire-policy]
}

resource "aws_iam_role_policy_attachment" "oidc-role-assume" {
  role       = aws_iam_role.oidc_role.name
  policy_arn = "${aws_iam_policy.oidc-federation-spire-policy.arn}"
  depends_on = [aws_iam_role.oidc_role]
}

