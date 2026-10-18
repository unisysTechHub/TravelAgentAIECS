data "aws_iam_policy_document" "task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "${var.service_name}-task"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role.json
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = 30
}

resource "aws_service_discovery_service" "this" {
  name = var.discovery_name

  dns_config {
    namespace_id = var.namespace_id

    dns_records {
      type = "A"
      ttl  = 60
    }

    routing_policy = "MULTIVALUE"
  }
}

locals {
  database_environment = var.database_url == null ? [] : [{
    name  = "DATABASE_URL"
    value = var.database_url
  }]

  database_secrets = var.database_secret_arn == null ? [] : [
    {
      name      = "DB_USER_NAME"
      valueFrom = "${var.database_secret_arn}:username::"
    },
    {
      name      = "DB_PASSWORD"
      valueFrom = "${var.database_secret_arn}:password::"
    }
  ]

  redis_secrets = var.redis_auth_secret_arn == null ? [] : [
    {
      name      = "REDIS_PASSWORD"
      valueFrom = "${var.redis_auth_secret_arn}:auth_token::"
    }
  ]

  shared_secrets = [
    for name, arn in var.shared_secret_arns : {
      name      = name
      valueFrom = arn
    }
  ]

  redis_environment = [
    for name, value in var.redis_environment : {
      name  = name
      value = value
    }
  ]

  service_url_environment = [
    for name, value in var.service_urls : {
      name  = name
      value = value
    }
  ]
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.service_name
  requires_compatibilities = ["EC2"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([merge({
    name      = lower(var.service_name)
    image     = var.image
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = concat(
      local.database_environment,
      local.redis_environment,
      local.service_url_environment
    )
    secrets = concat(local.database_secrets, local.redis_secrets, local.shared_secrets)

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }
    }, var.container_health_check_command == null ? {} : {
    healthCheck = {
      command     = var.container_health_check_command
      interval    = 30
      timeout     = 10
      retries     = 3
      startPeriod = 60
    }
  })])
}

resource "aws_ecs_service" "this" {
  name                               = lower(var.service_name)
  cluster                            = var.cluster_id
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = 1
  enable_execute_command             = true
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider_name
    weight            = 1
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn == null ? [] : [var.target_group_arn]
    content {
      target_group_arn = load_balancer.value
      container_name   = lower(var.service_name)
      container_port   = var.container_port
    }
  }

  service_registries {
    registry_arn = aws_service_discovery_service.this.arn
  }
}
