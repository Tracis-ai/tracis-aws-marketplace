output "request_api_urls" {
  value = {
    for key, receiver in local.request_receivers :
    key => "${module.api_gateway.api_endpoint}${receiver.path}"
  }
}

output "invoker_function_role" {
  description = "Execution role of Agent Invoker function"
  value = {
    arn  = module.lambda["invoker"].lambda_role_arn
    name = module.lambda["invoker"].lambda_role_name
  }
}
