terraform {
  backend "s3" {
    bucket  = "terraform-state-bucket-1-123-637452052867-ap-south-2-an"
    key     = "terraform.tfstate"
    region  = "ap-south-2"
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

locals {
  service_discovery_namespace = "travel"

  microservices = {
    TravelAgentService = { discovery_name = "travel-agent-ai-service", port = 8080, uses_postgres = true }
    # AdminService        = { discovery_name = "admin-service", port = 8081, uses_mysql = true }
    # AthorizationService = { discovery_name = "athorization-service", port = 8090, uses_mysql = true }
    FlightMCPService = { discovery_name = "flight-service", port = 8081, uses_postgres = true }
    HotelMCPService  = { discovery_name = "hotel-service", port = 8082, uses_postgres = false }
  }

  service_urls = {
    for service_key, service in local.microservices : service_key => "http://${service.discovery_name}.${local.service_discovery_namespace}:${service.port}"
  }
  shared_secret_arns = {
    WEATHER_API_KEY = data.aws_secretsmanager_secret.weather_api_key.arn
    OPENAI_API_KEY  = data.aws_secretsmanager_secret.openai_api_key.arn
  }

  # Inject only the service URLs each application is configured to consume.
  # UserService calls CoordinatorService; CoordinatorService calls TransactionService
  # and AccountService. The other services have no direct service URL dependencies.
  service_url_dependencies = {
    TravelAgentService = ["FlightMCPService", "HotelMCPService"]
    FlightMCPService   = []
    HotelMCPService    = []

  }
}



module "my_vpc" {
  source               = "../terraform-ecs-microservices/modules/vpc"
  name_prefix          = "banking-travel-dev"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  availability_zones   = ["ap-south-2a", "ap-south-2b"]
}

resource "aws_security_group" "microservices" {
  name        = "banking-travel-dev-microservices"
  description = "Shared outbound access for banking microservices"
  vpc_id      = module.my_vpc.vpc_id

  ingress {
    description = "Allow service-to-service traffic inside the ECS application group"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  ingress {
    from_port       = local.microservices.TravelAgentService.port
    to_port         = local.microservices.TravelAgentService.port
    protocol        = "tcp"
    security_groups = [module.alb.treavel_agent_alb_security_group_id]
  }

  ingress {
    from_port       = local.microservices.FlightMCPService.port
    to_port         = local.microservices.FlightMCPService.port
    protocol        = "tcp"
    security_groups = [aws_security_group.flight_mcp_client.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Managed with this stack so its ID is valid in the application VPC and its
# lifecycle follows Terraform. Attach this group to any client ENIs that need
# to call FlightMCPService.
resource "aws_security_group" "flight_mcp_client" {
  name        = "banking-travel-dev-flight-mcp-client"
  description = "Clients allowed to call FlightMCPService"
  vpc_id      = module.my_vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc_security_group_egress_rule" "alb_to_travel_agent_service" {
  security_group_id            = module.alb.treavel_agent_alb_security_group_id
  referenced_security_group_id = aws_security_group.microservices.id
  from_port                    = local.microservices.TravelAgentService.port
  to_port                      = local.microservices.TravelAgentService.port
  ip_protocol                  = "tcp"
  description                  = "Allow the ALB to forward UserService requests"
}

resource "aws_service_discovery_private_dns_namespace" "microservices" {
  name = local.service_discovery_namespace
  vpc  = module.my_vpc.vpc_id
}
module "alb" {
  source                       = "./ALB"
  name_prefix                  = "banking-travel-dev"
  vpc_id                       = module.my_vpc.vpc_id
  public_subnet_ids            = module.my_vpc.public_subnet_ids
  target_port                  = 8080
  listener_allowed_client_cidr = var.alb_listener_allowed_client_cidr
}
module "rds" {
  source                          = "./Postgres"
  name_prefix                     = "travel-voice-assist-dev-root"
  db_credentials_secret_name      = "banking-treavel-dev-root/rds/postgresql/credentials"
  vpc_id                          = module.my_vpc.vpc_id
  microservices_security_group_id = aws_security_group.microservices.id
  subnet_ids                      = module.my_vpc.private_subnet_ids
  availability_zones              = ["ap-south-2a", "ap-south-2b"]
  db_name                         = var.postgres_database_name
}


module "microservices" {
  for_each   = local.microservices
  source     = "./modules/ecs-microservice"
  depends_on = [aws_iam_role_policy.ecs_read_postgres_credentials]

  service_name     = each.key
  discovery_name   = each.value.discovery_name
  target_group_arn = each.key == "TravelAgentService" ? module.alb.travel_agent_Alb_target_group_arn : null
  image            = var.microservice_images[each.key]
  container_port   = each.value.port
  container_health_check_command = contains(["FlightMCPService", "HotelMCPService"], each.key) ? [
    "CMD-SHELL",
    "curl -fsS -X POST http://127.0.0.1:${each.value.port}/mcp -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\",\"params\":{}}' >/dev/null || exit 1"
  ] : null
  database_url        = each.value.uses_postgres ? "jdbc:postgresql://${module.rds.rds_endpoint}:5432/${var.postgres_database_name}" : null
  database_secret_arn = each.value.uses_postgres ? module.rds.db_credentials_secret_arn : null
  redis_environment   = {}
  service_urls = {
    for service_key in local.service_url_dependencies[each.key] :
    "DISCOVERY_${upper(replace(service_key, "Service", ""))}_SERVICE_URL" => local.service_urls[service_key]
  }
  shared_secret_arns     = local.shared_secret_arns
  cluster_id             = module.ecs_cluster.cluster_id
  capacity_provider_name = module.ecs_cluster.capacity_provider_name
  execution_role_arn     = module.ecs_cluster.execution_role_arn
  private_subnet_ids     = module.my_vpc.private_subnet_ids
  security_group_id      = aws_security_group.microservices.id
  namespace_id           = aws_service_discovery_private_dns_namespace.microservices.id
  aws_region             = var.aws_region


}

# ECS retrieves these values through the task execution role when it starts the
# container. Grant access only to the database and application secrets.
resource "aws_iam_role_policy" "ecs_read_postgres_credentials" {
  name = "read-task-secrets"
  role = module.ecs_cluster.execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["secretsmanager:GetSecretValue"]
      Resource = [
        module.rds.db_credentials_secret_arn,
        data.aws_secretsmanager_secret.weather_api_key.arn,
        data.aws_secretsmanager_secret.openai_api_key.arn,
      ]
    }]
  })
}

data "aws_secretsmanager_secret" "weather_api_key" {
  name = "banking-travel-dev/weather-api-key"
}

data "aws_secretsmanager_secret" "openai_api_key" {
  name = "banking-travel-dev/openai-api-key"
}

module "ecs_cluster" {
  source             = "../terraform-ecs-microservices/modules/ecs-cluster"
  name_prefix        = "banking-retail-dev"
  vpc_id             = module.my_vpc.vpc_id
  private_subnet_ids = module.my_vpc.private_subnet_ids
  ami_id             = data.aws_ssm_parameter.ecs_ami.value
  instance_type      = "t3.small"
}


