variable "domain_name" {
  type = string
  default = "unisystechhub.com"
}

resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "main"
  }
}