module "gateway_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.4.0"

  name            = "${var.prefix}-tracis-ai-tools-gateway-role"
  use_name_prefix = false

  trust_policy_permissions = {
    AssumeRolePolicy = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["bedrock-agentcore.amazonaws.com"]
      }]
      condition = [
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        },
        {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values = [
            "arn:aws:bedrock-agentcore:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*",
          ]
        },
      ]
    }
  }

  create_inline_policy = length(local.enabled_tools) > 0
  inline_policy_permissions = length(local.enabled_tools) == 0 ? {} : {
    ToolLambdaInvocation = {
      effect  = "Allow"
      actions = ["lambda:InvokeFunction"]
      resources = [
        for _, function in module.tool_functions.functions : function.arn
      ]
    }
    ToolSchemaRead = {
      effect  = "Allow"
      actions = ["s3:GetObject"]
      resources = [
        for key in keys(local.enabled_tool_configs) :
        "${module.tool_schema_bucket.s3_bucket_arn}/${local.tool_schema_object_keys[key]}"
      ]
    }
  }
}
