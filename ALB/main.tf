resource "aws_security_group" "alb_sg" {
    name        = "travel-agent-ai-alb-sg"
    description = "Security group for the ALB"
    vpc_id      = var.vpc_id

    ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
resource "aws_lb" "travel-agent-ai-alb" {
    name = "travel-agent-ai-alb"
    internal = false
    security_groups = [aws_security_group.alb_sg.id]
    subnets = var.public_subnet_ids
    load_balancer_type = "application"

}
resource "aws_lb_target_group" "travel-agent-ai-tg" {
    # Target type is immutable. Use a new name so Terraform can create the IP
    # target group before moving the listener rule off the existing group.
    name     = "travel-agent-ai-ip-tg"
    port     = 8080
    protocol = "HTTP"
    vpc_id   = var.vpc_id
    target_type = "ip"

    lifecycle {
        create_before_destroy = true
    }

    health_check {
        path                = "/actuator/health"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
        matcher             = "200-399"
    }
 
}

resource "aws_lb_listener" "travel-agent-ai-listener" {
    load_balancer_arn = aws_lb.travel-agent-ai-alb.arn
    port              =  8080   
    protocol          = "HTTP"

    default_action {
        type             = "fixed-response"
        fixed_response {
            content_type = "text/plain"
            message_body = "Not Found"
            status_code  = "404"
        }
    }
   
  
}

resource "aws_lb_listener_rule" "travel_agent_ai_service" {
    listener_arn = aws_lb_listener.travel-agent-ai-listener.arn
    priority     = 100

    action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.travel-agent-ai-tg.arn
    }

    condition {
        path_pattern {
            values = ["/api/*"]
        }
    }
}

