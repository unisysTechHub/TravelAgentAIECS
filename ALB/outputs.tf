output "travel_agent_Alb_dsn_name" {
  value = aws_lb.travel-agent-ai-alb.dns_name
}
output "travel_agent_Alb_arn" {
  value = aws_lb.travel-agent-ai-alb.arn
}
output "travel_agent_Alb_target_group_arn" {
  value = aws_lb_target_group.travel-agent-ai-tg.arn
}
output "treavel_agent_alb_security_group_id" {
  value = aws_security_group.alb_sg.id
}
