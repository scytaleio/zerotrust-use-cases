
data "tls_certificate" "scytale-oidc" {
  
  url = "https://${aws_route53_record.www.name}"

  depends_on = [time_sleep.wait_90_seconds]
}


resource "aws_iam_openid_connect_provider" "scytale-oidc" {
  url = "https://${aws_route53_record.www.name}"

  client_id_list = ["mys3",]

  thumbprint_list = [data.tls_certificate.scytale-oidc.certificates.0.sha1_fingerprint]

  depends_on = [data.tls_certificate.scytale-oidc]

}