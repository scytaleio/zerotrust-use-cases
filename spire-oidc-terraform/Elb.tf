# Create a new load balancer
resource "aws_elb" "oidc-elb" {
  name               = var.elbName
  availability_zones = ["us-west-1a"]
  security_groups    = var.securityGroups 

  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${aws_acm_certificate.default.id}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:8080/.well-known/openid-configuration"
    interval            = 30
  }

  instances                   = [aws_instance.linux_instance.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "oidc-elb"
  }

  depends_on = [aws_acm_certificate_validation.default]
}
