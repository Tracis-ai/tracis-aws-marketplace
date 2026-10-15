resource "aws_bedrockagentcore_gateway" "this" {
  name        = "${var.prefix}-tracis-ai-tools-gateway"
  description = "AgentCore Gateway for TracisAI tools"
  role_arn    = module.gateway_role.arn

  authorizer_type = "AWS_IAM"
  protocol_type   = "MCP"
}

resource "aws_bedrockagentcore_gateway_target" "this" {
  for_each = local.enabled_tool_configs

  name               = each.key
  gateway_identifier = aws_bedrockagentcore_gateway.this.gateway_id
  description        = each.value.description

  credential_provider_configuration {
    gateway_iam_role {}
  }

  target_configuration {
    mcp {
      lambda {
        lambda_arn = module.tool_functions.functions[each.key].arn

        tool_schema {
          s3 {
            uri = "s3://${module.tool_schema_bucket.s3_bucket_id}/${local.tool_schema_object_keys[each.key]}"
          }
        }
      }
    }
  }

  depends_on = [module.tool_schema_objects]
}
