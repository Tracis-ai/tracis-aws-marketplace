data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_subnet" "this" {
  count = length(local.enabled_vpc_tool_configs) > 0 ? 1 : 0

  id = var.lambda_subnet_ids[0]
}

data "aws_vpc" "this" {
  count = length(data.aws_subnet.this)

  id = data.aws_subnet.this[0].vpc_id
}
