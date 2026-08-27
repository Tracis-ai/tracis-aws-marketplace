data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_subnet" "agentcore" {
  id = var.subnet_ids[0]
}

data "aws_vpc" "agentcore" {
  id = data.aws_subnet.agentcore.vpc_id
}
