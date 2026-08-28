locals {
  subnet_ids              = compact(split(",", var.subnet_ids))
  mysql_sg_ids            = compact(split(",", var.mysql_security_group_ids))
  enabled_db_types        = compact(split(",", var.enabled_db_types))
  enable_mysql_connection = contains(local.enabled_db_types, "mysql")

  mysql_secret_arn      = trimspace(var.mysql_secret_arn)
  chat_tools_secret_arn = trimspace(var.chat_tools_secret_arn)
  effective_chat_tools_secret_arn = local.chat_tools_secret_arn != "" ? local.chat_tools_secret_arn : try(
    aws_secretsmanager_secret.chat_tools[0].arn,
    "",
  )

  agent_image_url         = trimspace(var.agent_image_url)
  default_agent_image_url = "709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracisai-free:20260828-095016-218a6dd4"
  expired_default_agent_image_urls = [
    "709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracis-free:20260520-125957-0fb7c715",
    "709825985650.dkr.ecr.us-east-1.amazonaws.com/btm/tracisai-free:20260826-113900-f19f9f21",
  ]
  effective_agent_image_url = (
    local.agent_image_url != "" &&
    !contains(local.expired_default_agent_image_urls, local.agent_image_url)
    ? local.agent_image_url
    : local.default_agent_image_url
  )

  pii_output_entity_types = (
    trimspace(var.pii_output_entity_types) == ""
    ? []
    : [
      for entity_type in split(",", var.pii_output_entity_types) :
      trimspace(entity_type) if trimspace(entity_type) != ""
    ]
  )
}
