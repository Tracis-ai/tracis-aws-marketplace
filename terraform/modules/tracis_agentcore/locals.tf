locals {
  runtime_name = substr(
    replace("${var.prefix}_tracis_ai_agent", "-", "_"),
    0,
    48,
  )

  image_repo_url = split(
    ":",
    split("@", var.container_image_url)[0]
  )[0]
  image_registry_host = split(
    "/",
    local.image_repo_url,
  )[0]
  image_registry = {
    id     = split(".", local.image_registry_host)[0]
    region = split(".", local.image_registry_host)[3]
  }
  image_repo_name = trimprefix(
    local.image_repo_url,
    "${local.image_registry_host}/",
  )
  image_repo_arn = "arn:aws:ecr:${local.image_registry.region}:${local.image_registry.id}:repository/${local.image_repo_name}"

  optional_env_vars = {
    for key, value in {
      BEDROCK_MODEL_ID = try(tostring(var.model_config.bedrock_model_id), null)
      MAX_TOKENS       = try(tostring(var.model_config.max_tokens), null)
      TEMPERATURE      = try(tostring(var.model_config.temperature), null)
      TOP_P            = try(tostring(var.model_config.top_p), null)
    } : key => value if value != null
  }

  environment_variables = merge(
    {
      TRACIS_RUNTIME_MODE                = "agent"
      TRACIS_RUNTIME_PLATFORM            = "agentcore"
      AGENT_PROCESS_TIMEOUT_SECONDS      = "300"
      LOG_LEVEL                          = "INFO"
      FASTMCP_LOG_LEVEL                  = "INFO"
      STATISTICS_LOG_GROUP_NAME          = aws_cloudwatch_log_group.statistics.name
      TOOL_GATEWAY_URL                   = var.gateway_tools_config.gateway_url
      ENABLE_MYSQL_TOOLS                 = tostring(contains(var.gateway_tools_config.enabled_tools, "mysql"))
      INPUT_GUARDRAIL_ID                 = aws_bedrock_guardrail.input.guardrail_id
      INPUT_GUARDRAIL_VERSION            = aws_bedrock_guardrail_version.input.version
      OUTPUT_GUARDRAIL_ID                = aws_bedrock_guardrail.output.guardrail_id
      OUTPUT_GUARDRAIL_VERSION           = aws_bedrock_guardrail_version.output.version
      GUARDRAIL_ID                       = aws_bedrock_guardrail.output.guardrail_id
      GUARDRAIL_VERSION                  = aws_bedrock_guardrail_version.output.version
      ENABLE_GUARDRAIL_TRACE             = try(tostring(var.model_config.enable_guardrail_trace), "disabled")
      KNOWLEDGE_BASE_ID                  = aws_bedrockagent_knowledge_base.this.id
      OTEL_RESOURCE_ATTRIBUTES           = "service.name=${local.runtime_name}"
      OTEL_EXPORTER_OTLP_PROTOCOL        = "http/protobuf"
      UNIFIED_TRACES_DESTINATION_ENABLED = "true"
    },
    local.optional_env_vars,
  )

  statistics_log_group_name = "/tracis-ai/statistics/${var.prefix}"
}
