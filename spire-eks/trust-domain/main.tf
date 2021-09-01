// spire-oidc ELB data resource
data "aws_lb" "get_lb_info" {
  name = "${var.elbname}"
}

// AWS Route53 data resource
data "aws_route53_zone" "external" {
  name = "${var.dnsZone}"
}

// AWS Route53 entry with lb record
resource "aws_route53_record" "www" {
  zone_id = "${data.aws_route53_zone.external.zone_id}"
  name    = "${var.trust_domain}"
  type    = "CNAME"
  records = ["${var.elb}"]
  ttl     = "60"
  depends_on = [data.aws_lb.get_lb_info]
}

// Wait time for AWS Route53 update
resource "time_sleep" "wait_90_seconds" {
  depends_on = [aws_route53_record.www]

  create_duration = "90s"
}

