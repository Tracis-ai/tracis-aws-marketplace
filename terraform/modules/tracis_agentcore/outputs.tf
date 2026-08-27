output "agentcore_runtime" {
  description = "AgentCore Runtime and default endpoint"
  value = {
    id       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
    arn      = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
    role_arn = module.agentcore_runtime_role.arn
  }
}

output "agent_api" {
  description = "Agent invocation configuration used by the request API module"
  value = {
    invocation_url    = "https://bedrock-agentcore.${data.aws_region.current.region}.amazonaws.com/runtimes/${urlencode(aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn)}/invocations?qualifier=DEFAULT"
    port              = local.agent_api.port
    security_group_id = aws_security_group.agentcore_runtime.id
    subnet_ids        = var.subnet_ids
  }
}

output "knowledge_bases" {
  description = "Knowledge Base and data source identifiers"
  value = {
    id             = aws_bedrockagent_knowledge_base.this.id
    data_source_id = aws_bedrockagent_data_source.this.data_source_id
    data_source_bucket = {
      arn  = module.kb_source_bucket.s3_bucket_arn
      name = module.kb_source_bucket.s3_bucket_id
    }
  }
}
