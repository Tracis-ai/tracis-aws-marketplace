resource "aws_security_group" "agentcore_runtime" {
  name        = "${var.prefix}-tracis-ai-agentcore-runtime-sg"
  description = "Security group for TracisAI AgentCore Runtime"
  vpc_id      = data.aws_subnet.agentcore.vpc_id

  tags = {
    Name = "${var.prefix}-tracis-ai-agentcore-runtime-sg"
  }

  timeouts {
    delete = "2m"
  }
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.agentcore_runtime.id
  description       = "Allow HTTPS access to AWS services and external APIs"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "dns_udp" {
  security_group_id = aws_security_group.agentcore_runtime.id
  description       = "Allow DNS queries within the VPC"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = data.aws_vpc.agentcore.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "dns_tcp" {
  security_group_id = aws_security_group.agentcore_runtime.id
  description       = "Allow DNS queries within the VPC"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = data.aws_vpc.agentcore.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "mysql" {
  for_each = var.mysql_connection.enabled ? toset(var.mysql_connection.db_security_group_ids) : toset([])

  security_group_id            = aws_security_group.agentcore_runtime.id
  description                  = "Allow MySQL access"
  ip_protocol                  = "tcp"
  from_port                    = var.mysql_connection.port
  to_port                      = var.mysql_connection.port
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "mysql_from_tracis_agent" {
  for_each = var.mysql_connection.enabled ? toset(var.mysql_connection.db_security_group_ids) : toset([])

  security_group_id            = each.value
  description                  = "Allow inbound from TracisAI AgentCore Runtime"
  ip_protocol                  = "tcp"
  from_port                    = var.mysql_connection.port
  to_port                      = var.mysql_connection.port
  referenced_security_group_id = aws_security_group.agentcore_runtime.id
}
