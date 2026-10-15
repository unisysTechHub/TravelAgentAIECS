output "ec2_rds-sg-id" {
  value = aws_security_group.ec2_sg.id
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "db_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the MySQL credentials"
  value       = data.aws_secretsmanager_secret_version.db_credentials.secret_arn
}
