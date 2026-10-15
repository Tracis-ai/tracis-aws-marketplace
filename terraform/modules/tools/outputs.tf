output "enabled_tools" {
  description = "Names of tools with configured container image"
  value       = local.enabled_tools
}

output "gateway_url" {
  description = "AgentCore Gateway URL"
  value       = aws_bedrockagentcore_gateway.this.gateway_url
}

output "tool_functions" {
  description = "Container Lambda function information keyed by enabled tool name"
  value       = module.tool_functions.functions
}
