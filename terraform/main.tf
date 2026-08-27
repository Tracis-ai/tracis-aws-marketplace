data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_secretsmanager_secret" "chat_tools" {
  count = local.chat_tools_secret_arn == "" ? 1 : 0

  name_prefix = "${var.prefix}-tracis-chat-tools-credentials"
}

resource "aws_secretsmanager_secret_version" "chat_tools" {
  count = local.chat_tools_secret_arn == "" ? 1 : 0

  secret_id = aws_secretsmanager_secret.chat_tools[0].id
  secret_string = jsonencode({
    SLACK_BOT_TOKEN        = ""
    SLACK_SIGNING_SECRET   = ""
    CHATWORK_WEBHOOK_TOKEN = ""
    CHATWORK_API_TOKEN     = ""
  })
}

# Secrets Manager secrets for MySQL credentials if not provided
resource "aws_secretsmanager_secret" "mysql" {
  count = local.mysql_secret_arn == "" ? 1 : 0

  name_prefix = "${var.prefix}-tracis-mysql-credentials"
}

resource "aws_secretsmanager_secret_version" "mysql" {
  count = local.mysql_secret_arn == "" ? 1 : 0

  secret_id = aws_secretsmanager_secret.mysql[0].id
  secret_string = jsonencode({
    username = ""
    password = ""
  })
}

# Main agent module
module "agent" {
  source = "./modules/tracis_agentcore"

  prefix              = var.prefix
  subnet_ids          = local.subnet_ids
  container_image_url = local.effective_agent_image_url
  model_config = {
    bedrock_model_id       = var.bedrock_model_id
    max_tokens             = var.max_tokens
    temperature            = 0.1
    enable_guardrail_trace = "enabled"
  }
  pii_output_entity_types = local.pii_output_entity_types
  mysql_connection = {
    enabled               = local.enable_mysql_connection
    host                  = var.mysql_endpoint
    port                  = var.mysql_port
    db_name               = var.mysql_db_name
    db_security_group_ids = local.mysql_sg_ids
    secret_arn = coalesce(
      local.mysql_secret_arn,
      try(aws_secretsmanager_secret.mysql[0].arn, null),
    )
  }
}

module "request_api" {
  source = "./modules/request_api"

  prefix               = var.prefix
  agent_invocation_url = module.agent.agent_api.invocation_url
  agentcore_config = {
    enabled     = true
    runtime_arn = module.agent.agentcore_runtime.arn
  }
  vpc_config = {
    enabled = false
  }
  chat_tools_secret_arn = local.effective_chat_tools_secret_arn
}
