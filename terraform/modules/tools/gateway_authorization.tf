data "aws_iam_policy_document" "gateway_resource" {
  statement {
    sid    = "AllowRuntimeInvocation"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["bedrock-agentcore:InvokeGateway"]
    resources = [aws_bedrockagentcore_gateway.this.gateway_arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [var.runtime_role.arn]
    }
  }

  statement {
    sid    = "DenyInvocationExceptRuntime"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["bedrock-agentcore:InvokeGateway"]
    resources = [aws_bedrockagentcore_gateway.this.gateway_arn]

    dynamic "condition" {
      for_each = length(local.enabled_tools) > 0 ? [1] : []

      content {
        test     = "ArnNotEquals"
        variable = "aws:PrincipalArn"
        values   = [var.runtime_role.arn]
      }
    }
  }
}

resource "aws_bedrockagentcore_resource_policy" "gateway" {
  policy       = data.aws_iam_policy_document.gateway_resource.json
  resource_arn = aws_bedrockagentcore_gateway.this.gateway_arn
}

data "aws_iam_policy_document" "invoke_gateway" {
  statement {
    sid       = "InvokeToolsGateway"
    actions   = ["bedrock-agentcore:InvokeGateway"]
    resources = [aws_bedrockagentcore_gateway.this.gateway_arn]
  }
}

resource "aws_iam_role_policy" "runtime_invoke_gateway" {
  name   = "invoke-gateway"
  policy = data.aws_iam_policy_document.invoke_gateway.json
  role   = var.runtime_role.name
}
