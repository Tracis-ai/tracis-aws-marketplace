output "knowledge_base_data_source_bucket_name" {
  value = module.agent.knowledge_bases.data_source_bucket.name
}

output "agentcore_runtime" {
  value = module.agent.agentcore_runtime
}

output "mysql_secret_name" {
  value = trimspace(var.mysql_secret_arn) == "" ? aws_secretsmanager_secret.mysql[0].name : null
}

output "request_api_urls" {
  value = module.request_api.request_api_urls
}

output "chat_tools_secret_name" {
  value = local.chat_tools_secret_arn == "" ? aws_secretsmanager_secret.chat_tools[0].name : null
}
