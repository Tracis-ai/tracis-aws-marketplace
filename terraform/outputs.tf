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

output "setup_app_web_url" {
  description = "TracisAI Setup Web URL, available after deployment when Setup is enabled"
  value       = try(module.setup_app[0].web_app_url, null)
}

output "setup_app_oidc_redirect_urls" {
  description = "TracisAI Setup OAuth callback URLs, available when Setup is enabled"
  value       = try(module.setup_app[0].oidc_redirect_urls, null)
}
