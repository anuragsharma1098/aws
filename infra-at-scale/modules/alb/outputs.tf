output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "https_listener_arns" {
  value = { for k, v in aws_lb_listener.https : k => v.arn }
}

output "blue_target_group_names" {
  value = { for k, v in aws_lb_target_group.blue : k => v.name }
}

output "green_target_group_names" {
  value = { for k, v in aws_lb_target_group.green : k => v.name }
}

output "blue_target_group_arns" {
  value = { for k, v in aws_lb_target_group.blue : k => v.arn }
}

output "green_target_group_arns" {
  value = { for k, v in aws_lb_target_group.green : k => v.arn }
}

output "blue_target_group_arn_suffixes" {
  value = { for k, v in aws_lb_target_group.blue : k => v.arn_suffix }
}
