data "aws_subnet" "this" {
  count = var.vpc_config.enabled ? 1 : 0

  id = var.vpc_config.subnet_ids[0]
}

resource "aws_security_group" "invoker" {
  count = var.vpc_config.enabled ? 1 : 0

  name        = "${var.prefix}-tracis-ai-agent-invoker-sg"
  description = "Security group for TracisAI Agent invoker Lambda"
  vpc_id      = data.aws_subnet.this[0].vpc_id
}

resource "aws_vpc_security_group_egress_rule" "invoker_to_agent" {
  count = var.vpc_config.enabled ? 1 : 0

  security_group_id            = aws_security_group.invoker[0].id
  ip_protocol                  = "tcp"
  from_port                    = var.vpc_config.agent_api_port
  to_port                      = var.vpc_config.agent_api_port
  referenced_security_group_id = var.vpc_config.agent_sg_id
  description                  = "Allow Agent invocation"
}

resource "aws_vpc_security_group_egress_rule" "invoker_to_aws_services" {
  count = var.vpc_config.enabled ? 1 : 0

  security_group_id = aws_security_group.invoker[0].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Allow AWS API calls through NAT Gateway"
}

resource "aws_vpc_security_group_ingress_rule" "agent_from_invoker" {
  count = var.vpc_config.enabled ? 1 : 0

  security_group_id            = var.vpc_config.agent_sg_id
  ip_protocol                  = "tcp"
  from_port                    = var.vpc_config.agent_api_port
  to_port                      = var.vpc_config.agent_api_port
  referenced_security_group_id = aws_security_group.invoker[0].id
  description                  = "Allow invocation from request API"
}

moved {
  from = aws_security_group.invoker
  to   = aws_security_group.invoker[0]
}

moved {
  from = aws_vpc_security_group_egress_rule.invoker_to_agent
  to   = aws_vpc_security_group_egress_rule.invoker_to_agent[0]
}

moved {
  from = aws_vpc_security_group_egress_rule.invoker_to_aws_services
  to   = aws_vpc_security_group_egress_rule.invoker_to_aws_services[0]
}

moved {
  from = aws_vpc_security_group_ingress_rule.agent_from_invoker
  to   = aws_vpc_security_group_ingress_rule.agent_from_invoker[0]
}
