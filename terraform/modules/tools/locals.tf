locals {
  tools = merge(
    var.mysql_connection.enabled ? {
      mysql = {
        description             = "MySQL Tool Lambda target"
        tool_schema_source_path = "${path.module}/tool_definitions/mysql.json"
        vpc_config = {
          target_sg_ids = var.mysql_connection.db_security_group_ids
          target_port   = var.mysql_connection.port
        }
      }
    } : {},
  )

  enabled_tool_configs = {
    for key, tool in local.tools : key => tool
    if var.container_image_urls[key] != null
  }

  enabled_vpc_tool_configs = {
    for key, tool in local.enabled_tool_configs : key => tool
    if tool.vpc_config != null
  }

  enabled_tools = toset(
    keys(local.enabled_tool_configs)
  )

  tool_schema_object_keys = {
    for key, tool in local.enabled_tool_configs :
    key => "tool-definitions/${key}-${filemd5(tool.tool_schema_source_path)}.json"
  }
}
