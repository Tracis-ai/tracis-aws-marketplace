locals {
  functions = merge(
    var.mysql_connection.enabled ? {
      mysql = {
        image_url   = var.container_image_urls.mysql
        handler     = var.handler
        memory_size = 256
        timeout     = 60
        environment_variables = {
          MYSQL_HOSTNAME   = var.mysql_connection.host
          MYSQL_PORT       = tostring(var.mysql_connection.port)
          MYSQL_DATABASE   = var.mysql_connection.db_name
          MYSQL_SECRET_ARN = var.mysql_connection.secret_arn
        }
        policy_statements = {
          "GetMysqlSecret" = {
            actions = [
              "secretsmanager:GetSecretValue",
            ]
            resources = [
              var.mysql_connection.secret_arn,
            ]
          }
        }
        vpc_config = {
          enabled    = true
          tool_sg_id = try(var.tool_sg_ids["mysql"], null)
        }
      }
    } : {},
  )

  enabled_functions = {
    for key, function in local.functions : key => function
    if contains(var.enabled_tools, key)
  }
}
