output "functions" {
  value = {
    for key, function in module.this :
    key => {
      arn               = function.lambda_function_arn
      name              = function.lambda_function_name
      security_group_id = try(var.tool_sg_ids[key], null)
    }
  }
}
