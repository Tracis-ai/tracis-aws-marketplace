data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  auth_functions = {
    for key, receiver in local.receiver_functions :
    key => receiver if receiver.type == "auth"
  }

  enqueue_functions = {
    for key, receiver in local.receiver_functions :
    key => receiver if receiver.type == "enqueue"
  }

  sqs_consumer_functions = merge(
    local.invoker_function,
    local.dispatcher_function,
  )
}

data "archive_file" "lambda_zip" {
  for_each = local.lambda_functions

  type        = "zip"
  source_dir  = each.value.source_dir
  excludes    = ["**/__pycache__/**", "**/*.pyc"]
  output_path = "${path.root}/archive/request_api/${each.key}-function.zip"
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "lambda_powertools_layer" {
  name           = "${var.prefix}-tracis-ai-lambda-powertools-python-layer-v3-python314-arm64"
  application_id = "arn:aws:serverlessrepo:eu-west-1:057560766410:applications/aws-lambda-powertools-python-layer-v3-python314-arm64"
  # https://serverlessrepo.aws.amazon.com/applications/eu-west-1/057560766410/aws-lambda-powertools-python-layer-v3-python314-arm64

  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
  ]

  tags = {
    Name = "${var.prefix}-tracis-ai-lambda-powertools-python-layer-v3-python314-arm64"
  }
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.5.0"

  for_each = local.lambda_functions

  function_name = each.value.name
  architectures = ["arm64"]
  runtime       = "python3.14"
  handler       = "app.lambda_handler"
  memory_size   = 128
  timeout       = each.value.timeout

  vpc_subnet_ids = (
    each.value.type == "invoker" && var.vpc_config.enabled
    ? var.vpc_config.subnet_ids
    : null
  )
  vpc_security_group_ids = (
    each.value.type == "invoker" && var.vpc_config.enabled
    ? [aws_security_group.invoker[0].id]
    : null
  )
  attach_network_policy = each.value.type == "invoker" && var.vpc_config.enabled

  layers = [
    aws_serverlessapplicationrepository_cloudformation_stack.lambda_powertools_layer.outputs["LayerVersionArn"],
  ]
  create_package         = false
  local_existing_package = data.archive_file.lambda_zip[each.key].output_path

  environment_variables = merge(
    each.value.type == "auth" ? {
      "ENQUEUE_FUNCTION_NAME" = local.receiver_functions["${each.value.platform}-enqueue"].name
    } : {},
    each.value.type == "enqueue" ? {
      "SQS_QUEUE_URL" = module.sqs["request"].queue_url
    } : {},
    contains(["auth", "enqueue"], each.value.type) ? {
      "CHAT_TOOLS_SECRET_ARN" = var.chat_tools_secret_arn
    } : {},
    each.value.type == "invoker" ? {
      "AGENT_INVOCATION_URL"       = var.agent_invocation_url
      "SETUP_LINKS_INVOCATION_URL" = var.setup_config.enabled ? trimspace(var.setup_config.invocation_url) : ""
      "INVOCATION_TIMEOUT_SECONDS" = tostring(each.value.timeout - 10)
      "RESPONSE_QUEUE_URL"         = module.sqs["response"].queue_url
    } : {},
    each.value.type == "dispatcher" ? {
      "CHAT_TOOLS_SECRET_ARN" = var.chat_tools_secret_arn
    } : {},
  )

  role_name                = "${each.value.name}-role"
  attach_policy_statements = true
  policy_name              = "${each.key}-function"
  policy_statements = merge(
    each.value.secret_arn != null ? {
      "get-secret" = {
        actions = [
          "secretsmanager:GetSecretValue",
        ]
        resources = [each.value.secret_arn]
      }
    } : {},
    each.value.type == "enqueue" ? {
      "enqueue-request-queue" = {
        actions = [
          "sqs:SendMessage",
        ]
        resources = [module.sqs["request"].queue_arn]
      }
    } : {},
    each.value.type == "invoker" ? {
      "consume-request-queue" = {
        actions = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        resources = [module.sqs["request"].queue_arn]
      }
      "enqueue-response-queue" = {
        actions = [
          "sqs:SendMessage",
        ]
        resources = [module.sqs["response"].queue_arn]
      }
    } : {},
    each.value.type == "invoker" && var.agentcore_config.enabled ? {
      "invoke-agentcore-runtime" = {
        actions = [
          "bedrock-agentcore:InvokeAgentRuntime",
        ]
        resources = [
          var.agentcore_config.runtime_arn,
          "${var.agentcore_config.runtime_arn}/runtime-endpoint/DEFAULT",
        ]
      }
    } : {},
    each.value.type == "dispatcher" ? {
      "consume-response-queue" = {
        actions = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        resources = [module.sqs["response"].queue_arn]
      }
    } : {},
  )

  cloudwatch_logs_retention_in_days = 14

  tags = {
    Name = each.value.name
  }
}

# Invocation permissions for Auth functions
data "aws_iam_policy_document" "auth_function_access_boundary" {
  for_each = local.auth_functions

  statement {
    sid     = "AllowInvocationFromApiGateway"
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.lambda[each.key].lambda_function_arn,
      "${module.lambda[each.key].lambda_function_arn}:*",
    ]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values = [
        "${module.api_gateway.api_execution_arn}/$default/POST${local.request_receivers[each.value.platform].path}",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "DenyUnexpectedServicePrincipal"
    effect  = "Deny"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.lambda[each.key].lambda_function_arn,
      "${module.lambda[each.key].lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalServiceName"
      values   = ["apigateway.amazonaws.com"]
    }
  }

  statement {
    sid     = "DenyUnexpectedSourceArn"
    effect  = "Deny"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.lambda[each.key].lambda_function_arn,
      "${module.lambda[each.key].lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:SourceArn"
      values = [
        "${module.api_gateway.api_execution_arn}/$default/POST${local.request_receivers[each.value.platform].path}",
      ]
    }
  }

  statement {
    sid     = "DenyUnexpectedSourceAccount"
    effect  = "Deny"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.lambda[each.key].lambda_function_arn,
      "${module.lambda[each.key].lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "DenyFunctionUrl"
    effect  = "Deny"
    actions = ["lambda:InvokeFunctionUrl"]
    resources = [
      module.lambda[each.key].lambda_function_arn,
      "${module.lambda[each.key].lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_lambda_resource_policy" "auth_function_access_boundary" {
  for_each = local.auth_functions

  resource_arn = module.lambda[each.key].lambda_function_arn
  policy       = data.aws_iam_policy_document.auth_function_access_boundary[each.key].json
}

# Invocation permissions for Enqueue functions
data "aws_iam_policy_document" "enqueue_function_access_boundary" {
  for_each = local.enqueue_functions

  statement {
    sid     = "AllowInvocationFromAuthFunctionRole"
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.lambda[each.key].lambda_function_arn,
      "${module.lambda[each.key].lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [module.lambda["${each.value.platform}-auth"].lambda_role_arn]
    }
  }

  statement {
    sid     = "DenyUnexpectedPrincipal"
    effect  = "Deny"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.lambda[each.key].lambda_function_arn,
      "${module.lambda[each.key].lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = [module.lambda["${each.value.platform}-auth"].lambda_role_arn]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalServiceName"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid     = "DenyFunctionUrl"
    effect  = "Deny"
    actions = ["lambda:InvokeFunctionUrl"]
    resources = [
      module.lambda[each.key].lambda_function_arn,
      "${module.lambda[each.key].lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_lambda_resource_policy" "enqueue_function_access_boundary" {
  for_each = local.enqueue_functions

  resource_arn = module.lambda[each.key].lambda_function_arn
  policy       = data.aws_iam_policy_document.enqueue_function_access_boundary[each.key].json
}

# Invocation permissions for SQS consumer functions (invoker / dispatcher)
data "aws_iam_policy_document" "sqs_consumer_function_access_boundary" {
  for_each = local.sqs_consumer_functions

  statement {
    sid     = "DenyUnexpectedServicePrincipal"
    effect  = "Deny"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.lambda[each.key].lambda_function_arn,
      "${module.lambda[each.key].lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalServiceName"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid     = "DenyFunctionUrl"
    effect  = "Deny"
    actions = ["lambda:InvokeFunctionUrl"]
    resources = [
      module.lambda[each.key].lambda_function_arn,
      "${module.lambda[each.key].lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_lambda_resource_policy" "sqs_consumer_function_access_boundary" {
  for_each = local.sqs_consumer_functions

  resource_arn = module.lambda[each.key].lambda_function_arn
  policy       = data.aws_iam_policy_document.sqs_consumer_function_access_boundary[each.key].json
}

resource "aws_lambda_event_source_mapping" "invoker_from_sqs" {
  event_source_arn        = module.sqs["request"].queue_arn
  function_name           = module.lambda["invoker"].lambda_function_name
  batch_size              = 1
  function_response_types = ["ReportBatchItemFailures"]

  depends_on = [
    module.lambda["invoker"],
    aws_sqs_queue_policy.sqs_massage_access,
  ]
}

resource "aws_lambda_event_source_mapping" "dispatcher_from_sqs" {
  event_source_arn        = module.sqs["response"].queue_arn
  function_name           = module.lambda["dispatcher"].lambda_function_name
  batch_size              = 1
  function_response_types = ["ReportBatchItemFailures"]

  depends_on = [
    module.lambda["dispatcher"],
    aws_sqs_queue_policy.sqs_massage_access,
  ]
}
