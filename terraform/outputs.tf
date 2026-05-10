output "knowledge_base_data_source_bucket_name" {
  value = module.agent.kb_data_source_bucket.name
}

output "mysql_secret_name" {
  value = trimspace(var.mysql_secret_arn) == "" ? aws_secretsmanager_secret.mysql[0].name : null
}

output "slack_receive_api_url" {
  value = module.slack_receiver.slack_receive_api_url
}

output "slack_secret_name" {
  value = trimspace(var.slack_secret_arn) == "" ? aws_secretsmanager_secret.slack[0].name : null
}
