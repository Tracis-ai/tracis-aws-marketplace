output "web_app_url" {
  description = "URL of the web application for TracisAI Setup"
  value       = "https://${module.web_distribution.cloudfront_distribution_domain_name}"
}

output "oidc_redirect_urls" {
  description = "OIDC redirect URLs for TracisAI Setup"
  value = {
    for chat_tool, redirect_path in local.oidc_redirect_paths :
    chat_tool => "https://${module.web_distribution.cloudfront_distribution_domain_name}/${redirect_path}"
  }
}

output "setup_links_api" {
  description = "Setup Links invocation configuration used by the request API module"
  value = {
    invocation_url = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${data.aws_region.current.region}.amazonaws.com/${aws_api_gateway_stage.this.stage_name}/api/setup-links"
  }
}

output "setup_api_function" {
  description = "Information of the API Lambda function for TracisAI Setup"
  value = {
    arn  = module.setup_api_function.lambda_function_arn
    name = module.setup_api_function.lambda_function_name
  }
}

output "mysql_schema_reader_function" {
  description = "MySQL schema reader Lambda function information"
  value       = try(module.schema_reader.functions["mysql"], null)
}
