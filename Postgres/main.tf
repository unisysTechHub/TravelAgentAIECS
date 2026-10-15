#################################
# Security Groups
#################################

# Allow MySQL inbound traffic from the shared ECS application security group.
# Security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "${var.name_prefix}-rds-sg"
  description = "Allow MySQL from ECS/EC2 SG"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EC2/ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.microservices_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for EC2/ECS
resource "aws_security_group" "ec2_sg" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Allow SSH and DB traffic to RDS"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ⚠️ Restrict in production
  }

  egress {
    description = "MySQL to RDS SG"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }
}

#################################
# Subnet Group for RDS
#################################
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.name_prefix}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "rds-subnet-group"
  }
}

#################################
# RDS MySQL Instance
#################################
# multi_az = true → enables synchronous standby in another AZ.

# availability_zone → only applies for single-AZ, ignored if multi_az = true.

# db_subnet_group_name → should include subnets in multiple AZs (required for Multi
data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = var.db_credentials_secret_name
}

locals {
  db_credentials = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)
}

resource "aws_db_instance" "postgres" {
  identifier              = "${var.name_prefix}-postgres-db"
  engine                  = "postgres"
  # Pin the major version and let RDS select a currently available minor release.
  engine_version          = "13"
  db_name                 = var.db_name
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  max_allocated_storage   = 100
  db_subnet_group_name    = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  username                = local.db_credentials.username
  password                = local.db_credentials.password
  port                    = 5432
  skip_final_snapshot     = true
  availability_zone       = var.availability_zones[1]
  backup_retention_period = 7
  deletion_protection     = false
  multi_az                = false

  tags = {
    Name = "my-postgres-db"
    Env  = "dev"
  }
}

#################################
# EC2 Instance (Bastion / App server)
#################################
