module "this" {
  source   = "terraform-aws-modules/lambda/aws"
  version  = "8.5.0"
  for_each = local.enabled_functions

  function_name = "${var.prefix}-${each.key}-tool-function"

  architectures  = ["arm64"]
  create_package = false
  package_type   = "Image"
  image_uri      = each.value.image_url
  image_config_command = each.value.handler != null ? [
    each.value.handler
  ] : []
  memory_size           = each.value.memory_size
  timeout               = each.value.timeout
  environment_variables = each.value.environment_variables

  role_name = "${var.prefix}-${each.key}-tool-function-role"
  attach_policy_statements = (
    length(each.value.policy_statements) > 0
    || each.value.vpc_config.enabled
  )
  policy_statements = merge(
    each.value.policy_statements,
    each.value.vpc_config.enabled ? {
      "DescribeSubnets" = {
        actions   = ["ec2:DescribeSubnets"]
        resources = ["*"]
      }
    } : {},
  )
  attach_network_policy = each.value.vpc_config.enabled

  vpc_subnet_ids = each.value.vpc_config.enabled ? var.subnet_ids : []
  vpc_security_group_ids = each.value.vpc_config.enabled ? [
    each.value.vpc_config.tool_sg_id
  ] : []

  cloudwatch_logs_retention_in_days  = 14
  attach_create_log_group_permission = false
}
