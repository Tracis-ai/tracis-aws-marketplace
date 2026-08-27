module "agentcore_runtime_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.4.0"

  name            = "${var.prefix}-tracis-ai-agentcore-runtime-role"
  use_name_prefix = false

  trust_policy_permissions = {
    AssumeRolePolicy = {
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals = [
        {
          type        = "Service"
          identifiers = ["bedrock-agentcore.amazonaws.com"]
        },
      ]
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

  create_inline_policy = true
  inline_policy_permissions = merge({
    AgentCoreRuntimeEcrAuthorization = {
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
    AgentCoreRuntimeEcrImagePull = {
      effect = "Allow"
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
      ]
      resources = [local.image_repo_arn]
    }
    AgentCoreRuntimeLogGroupCreation = {
      effect    = "Allow"
      actions   = ["logs:CreateLogGroup"]
      resources = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*"]
    }
    AgentCoreRuntimeLogging = {
      effect = "Allow"
      actions = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      resources = [
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*",
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/*:log-stream:*",
      ]
    }
    AgentCoreRuntimeObservability = {
      effect = "Allow"
      actions = [
        "logs:DescribeLogGroups",
        "logs:PutResourcePolicy",
      ]
      resources = [
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock-agentcore/runtimes/${local.runtime_name}-*",
      ]
    }
    AgentCoreRuntimeStatisticsLogging = {
      effect = "Allow"
      actions = [
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
      ]
      resources = ["${aws_cloudwatch_log_group.statistics.arn}:*"]
    }
    AgentCoreRuntimeMetricsPublication = {
      effect    = "Allow"
      actions   = ["cloudwatch:PutMetricData"]
      resources = ["*"]
      condition = [
        {
          test     = "StringEquals"
          variable = "cloudwatch:namespace"
          values   = ["bedrock-agentcore"]
        },
      ]
    }
    AgentCoreRuntimeXRayTracing = {
      effect = "Allow"
      actions = [
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets",
        "xray:PutTelemetryRecords",
        "xray:PutTraceSegments",
      ]
      resources = ["*"]
    }
    BedrockGuardrailApplication = {
      effect  = "Allow"
      actions = ["bedrock:ApplyGuardrail"]
      resources = [
        aws_bedrock_guardrail.input.guardrail_arn,
        aws_bedrock_guardrail.output.guardrail_arn,
        "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:guardrail-profile/${local.guardrail_profile_id}",
      ]
    }
    BedrockGuardrailConfiguration = {
      effect  = "Allow"
      actions = ["bedrock:GetGuardrail"]
      resources = [
        aws_bedrock_guardrail.input.guardrail_arn,
        aws_bedrock_guardrail.output.guardrail_arn,
      ]
    }
    BedrockKnowledgeBaseRetrieval = {
      effect    = "Allow"
      actions   = ["bedrock:Retrieve"]
      resources = [aws_bedrockagent_knowledge_base.this.arn]
    }
    BedrockModelInvocation = {
      effect = "Allow"
      actions = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
      ]
      resources = [
        "arn:aws:bedrock:*::foundation-model/*",
        "arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:inference-profile/*",
      ]
    }
    BedrockModelSubscription = {
      effect    = "Allow"
      actions   = ["aws-marketplace:Subscribe"]
      resources = ["*"]
    }
    CloudWatchLogsQuery = {
      effect = "Allow"
      actions = [
        "logs:DescribeLogGroups",
        "logs:DescribeQueryDefinitions",
        "logs:GetQueryResults",
        "logs:ListAnomalies",
        "logs:ListLogAnomalyDetectors",
        "logs:StartQuery",
        "logs:StopQuery",
      ]
      resources = ["*"]
    }
    },
    length(local.enabled_db_secret_arns) > 0 ? {
      DatabaseSecretRetrieval = {
        effect    = "Allow"
        actions   = ["secretsmanager:GetSecretValue"]
        resources = local.enabled_db_secret_arns
      }
    } : {},
  )
}
