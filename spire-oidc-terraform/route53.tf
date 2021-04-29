resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.external.zone_id}"
  name    = var.domainName 
  type    = "A"

  alias {
    name                   = aws_elb.oidc-elb.dns_name
    zone_id                = aws_elb.oidc-elb.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_elb.oidc-elb]
}

resource "time_sleep" "wait_90_seconds" {
  depends_on = [aws_route53_record.www]

  create_duration = "90s"
}