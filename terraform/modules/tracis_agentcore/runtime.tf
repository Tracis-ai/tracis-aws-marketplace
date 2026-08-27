# Omit authorizer_configuration to use AgentCore's default IAM SigV4 inbound authorization.
resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = local.runtime_name
  description        = "AgentCore Runtime for TracisAI Agent"
  role_arn           = module.agentcore_runtime_role.arn

  agent_runtime_artifact {
    container_configuration {
      container_uri = var.container_image_url
    }
  }

  environment_variables = local.environment_variables

  network_configuration {
    network_mode = "VPC"

    network_mode_config {
      security_groups = [
        aws_security_group.agentcore_runtime.id,
      ]
      subnets = var.subnet_ids
    }
  }

  protocol_configuration {
    server_protocol = "HTTP"
  }
}
