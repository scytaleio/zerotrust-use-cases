output "elb_zone_id" {
  description = "ELB Zone ID"
  value = data.aws_lb.get_lb_info.zone_id
}

