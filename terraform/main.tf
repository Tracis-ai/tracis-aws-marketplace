data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Secrets Manager secrets for Slack credentials if not provided
resource "aws_secretsmanager_secret" "slack" {
  count = trimspace(var.slack_secret_arn) == "" ? 1 : 0

  name_prefix = "${var.prefix}-tracis-slack-credentials"
}

resource "aws_secretsmanager_secret_version" "slack" {
  count = trimspace(var.slack_secret_arn) == "" ? 1 : 0

  secret_id = aws_secretsmanager_secret.slack[0].id
  secret_string = jsonencode({
    SLACK_BOT_TOKEN = ""
    SIGNING_SECRET  = ""
  })
}

# Secrets Manager secrets for MySQL credentials if not provided
resource "aws_secretsmanager_secret" "mysql" {
  count = trimspace(var.mysql_secret_arn) == "" ? 1 : 0

  name_prefix = "${var.prefix}-tracis-mysql-credentials"
}

resource "aws_secretsmanager_secret_version" "mysql" {
  count = trimspace(var.mysql_secret_arn) == "" ? 1 : 0

  secret_id = aws_secretsmanager_secret.mysql[0].id
  secret_string = jsonencode({
    username = ""
    password = ""
  })
}

# Main agent module
module "agent" {
  source = "./modules/tracis_agent"

  prefix                    = var.prefix
  subnet_ids                = split(",", var.subnet_ids)
  ecs_service_desired_count = var.ecs_service_desired_count
  use_fargate_spot          = var.enable_fargate_spot
  container_image_url       = var.agent_image_url
  model_config = {
    bedrock_model_id = var.bedrock_model_id
    max_tokens       = var.max_tokens
    temperature      = 0.1
  }
  slack_secret_arn = coalesce(
    trimspace(var.slack_secret_arn),
    try(aws_secretsmanager_secret.slack[0].arn, null),
  )
  mysql_connection = {
    host                  = var.mysql_endpoint
    port                  = var.mysql_port
    db_name               = var.mysql_db_name
    db_security_group_ids = split(",", var.mysql_security_group_ids)
    secret_arn = coalesce(
      trimspace(var.mysql_secret_arn),
      try(aws_secretsmanager_secret.mysql[0].arn, null),
    )
  }
}

# Slack receiver module
module "slack_receiver" {
  source = "./modules/slack_receiver"

  prefix = var.prefix
  slack_secret_arn = coalesce(
    trimspace(var.slack_secret_arn),
    try(aws_secretsmanager_secret.slack[0].arn, null),
  )
  sqs_queue = module.agent.sqs_queue
}
