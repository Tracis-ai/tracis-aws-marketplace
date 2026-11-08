locals {
  invocation_resource_arns = var.agentcore_config.enabled ? {
    runtime          = var.agentcore_config.runtime_arn
    default_endpoint = "${var.agentcore_config.runtime_arn}/runtime-endpoint/DEFAULT"
  } : {}
}

# Invocation permissions for AgentCore Runtime
data "aws_iam_policy_document" "agentcore_runtime_invocation" {
  for_each = local.invocation_resource_arns

  statement {
    sid       = "AllowInvokerLambda"
    effect    = "Allow"
    actions   = ["bedrock-agentcore:InvokeAgentRuntime"]
    resources = [each.value]

    principals {
      type        = "AWS"
      identifiers = [module.lambda["invoker"].lambda_role_arn]
    }
  }

  statement {
    sid       = "DenyNonInvokerPrincipals"
    effect    = "Deny"
    actions   = ["bedrock-agentcore:InvokeAgentRuntime"]
    resources = [each.value]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = [module.lambda["invoker"].lambda_role_arn]
    }
  }
}

resource "aws_bedrockagentcore_resource_policy" "agentcore_runtime_invocation" {
  for_each = local.invocation_resource_arns

  policy       = data.aws_iam_policy_document.agentcore_runtime_invocation[each.key].json
  resource_arn = each.value
}
