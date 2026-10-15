module "tool_functions" {
  source = "./lambda"

  prefix               = "${var.prefix}-tracis-ai"
  enabled_tools        = keys(local.enabled_tool_configs)
  container_image_urls = var.container_image_urls
  subnet_ids           = var.lambda_subnet_ids
  tool_sg_ids = {
    for key, _ in local.enabled_vpc_tool_configs :
    key => module.tool_function_security_groups[key].id
  }
  mysql_connection = var.mysql_connection
}

module "tool_function_security_groups" {
  source   = "terraform-aws-modules/security-group/aws"
  version  = "6.0.0"
  for_each = local.enabled_vpc_tool_configs

  name            = "${var.prefix}-tracis-ai-${each.key}-tool-function-sg"
  use_name_prefix = false
  description     = "Security group for ${each.key} tool function"
  vpc_id          = data.aws_vpc.this[0].id

  egress_rules = merge(
    {
      https = {
        description = "Allow HTTPS access outbounds"
        ip_protocol = "tcp"
        from_port   = 443
        to_port     = 443
        cidr_ipv4   = "0.0.0.0/0"
      }
      dns_udp = {
        description = "Allow DNS queries within the VPC"
        ip_protocol = "udp"
        from_port   = 53
        to_port     = 53
        cidr_ipv4   = data.aws_vpc.this[0].cidr_block
      }
      dns_tcp = {
        description = "Allow DNS queries within the VPC"
        ip_protocol = "tcp"
        from_port   = 53
        to_port     = 53
        cidr_ipv4   = data.aws_vpc.this[0].cidr_block
      }
    },
    {
      for target_sg_id in each.value.vpc_config.target_sg_ids :
      target_sg_id => {
        description                  = "Allow DB connection to ${each.key}"
        ip_protocol                  = "tcp"
        from_port                    = each.value.vpc_config.target_port
        to_port                      = each.value.vpc_config.target_port
        referenced_security_group_id = target_sg_id
      }
    },
  )

  tags = {
    Name = "${var.prefix}-tracis-ai-${each.key}-tool-function-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_tool" {
  for_each = (
    contains(keys(local.enabled_vpc_tool_configs), "mysql")
    ? toset(var.mysql_connection.db_security_group_ids)
    : toset([])
  )

  security_group_id            = each.value
  description                  = "Allow inbound from the TracisAI MySQL Tool Lambda"
  ip_protocol                  = "tcp"
  from_port                    = var.mysql_connection.port
  to_port                      = var.mysql_connection.port
  referenced_security_group_id = module.tool_function_security_groups["mysql"].id
}
