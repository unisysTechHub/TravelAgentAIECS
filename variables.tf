variable "aws_region" {
  description = "AWS Region for this deployment."
  type        = string
  default     = "ap-south-2"
}

variable "frontend_image" {
  description = "Immutable ECR image URI for the frontend container."
  type        = string
}

variable "postgres_database_name" {
  description = "PostgreSQL database schema used by the services"
  type        = string
  default     = "spring_ai"
}

variable "redis_credentials_secret_name" {
  description = "Name of the Secrets Manager secret containing the Redis AUTH token"
  type        = string
  default     = "banking-retail-dev-root/redis/credentials"
}

variable "microservice_images" {
  description = "ECR image URI for each backend service (TravelAgentService, FlightMCPService, HotelMCPService)"
  type        = map(string)

  validation {
    condition = alltrue([
      for service_name in ["TravelAgentService", "FlightMCPService", "HotelMCPService"] :
      contains(keys(var.microservice_images), service_name) && trimspace(lookup(var.microservice_images, service_name, "")) != ""
    ])
    error_message = "microservice_images must define a non-empty ECR image URI for all three services."
  }
}

