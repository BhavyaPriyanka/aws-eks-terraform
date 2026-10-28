output "frontend_target_group_arn" {
  description = "ARN of the LocalHelp frontend target group"
  value       = aws_lb_target_group.frontend.arn
}

output "prometheus_target_group_arn" {
  description = "ARN of the LocalHelp prometheus target group"
  value = aws_lb_target_group.prometheus.arn
}

output "grafana_target_group_arn" {
  description = "ARN of the LocalHelp grafana target group"
  value = aws_lb_target_group.grafana.arn
}
