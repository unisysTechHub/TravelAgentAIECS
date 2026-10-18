variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" {
  type = list(string)
  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "A public ALB requires subnets in at least two Availability Zones."
  }
}
variable "target_port" { type = number }
variable "listener_allowed_client_cidr" {
  description = "CIDR allowed to reach the ALB listener on port 8080."
  type        = string
}
variable "health_check_path" {
  type    = string
  default = "/healthz"
}
