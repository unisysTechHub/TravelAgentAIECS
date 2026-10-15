#################################
# Provider
#################################


#################################
# Variables
#################################
variable "name_prefix" {
  description = "Prefix used to name database resources and its Secrets Manager secret"
  type        = string
}

variable "db_credentials_secret_name" {
  description = "Name or ARN of the Secrets Manager secret with username and password fields"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "spring_ai"
}

variable "vpc_id" {
  description = "VPC ID where DB will be created"
  type        = string
}

variable "microservices_security_group_id" {
  description = "Shared ECS security group allowed to connect to MySQL"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for DB subnet group"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

