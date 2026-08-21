output "sns_topic_arn" {
  value = aws_sns_topic.alarms.arn
}

output "alarm_arns" {
  description = "Feed into ecs-service-bluegreen's alarm_arns for CodeDeploy auto-rollback"
  value = [
    aws_cloudwatch_metric_alarm.alb_5xx.arn,
    aws_cloudwatch_metric_alarm.target_unhealthy.arn,
  ]
}

output "dashboard_name" {
  value = aws_cloudwatch_dashboard.this.dashboard_name
}
