output "frontend_target_group_arn" {
  description = "ARN of the LocalHelp frontend target group"
  value       = aws_lb_target_group.frontend.arn
}
