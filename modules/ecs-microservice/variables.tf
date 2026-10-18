variable "service_name" {
  type = string
}

variable "discovery_name" {
  type = string
}

variable "target_group_arn" {
  type    = string
  default = null
}

variable "service_urls" {
  type    = map(string)
  default = {}
}

variable "image" {
  type = string
}

variable "container_port" {
  type = number
}

variable "container_health_check_command" {
  description = "Optional command to run inside the container for ECS health checks."
  type        = list(string)
  default     = null
}

variable "database_url" {
  type    = string
  default = null
}

variable "database_secret_arn" {
  type    = string
  default = null
}

variable "redis_auth_secret_arn" {
  type    = string
  default = null
}

variable "redis_environment" {
  type    = map(string)
  default = {}
}

variable "shared_secret_arns" {
  description = "Secrets Manager ARNs exposed as environment variables to every microservice task."
  type        = map(string)
  default     = {}
}

variable "cluster_id" {
  type = string
}

variable "capacity_provider_name" {
  type = string
}

variable "execution_role_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "namespace_id" {
  type = string
}

variable "aws_region" {
  type = string
}
