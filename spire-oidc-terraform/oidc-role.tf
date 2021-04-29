resource "aws_iam_role" "oidc_role" {
  name = var.instanceName
  assume_role_policy =  templatefile("files/oidc_assume_role_policy.json", { OIDC_ARN = aws_iam_openid_connect_provider.scytale-oidc.arn, OIDC_URL = replace(aws_iam_openid_connect_provider.scytale-oidc.url, "https://", "") })
depends_on = [aws_iam_openid_connect_provider.scytale-oidc]
}

resource "aws_iam_role_policy_attachment" "oidc-role-assume" {
  role       = aws_iam_role.oidc_role.name
  policy_arn = "${aws_iam_policy.oidc-federation-spire-policy.arn}"
depends_on = [aws_iam_role.oidc_role]
}