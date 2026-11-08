data "archive_file" "stats_logs_forwarder" {
  type        = "zip"
  source_dir  = "${path.module}/src/lambda/statistics_logs_forwarder"
  output_path = "${path.root}/archive/tracis_agentcore/statistics_logs_forwarder.zip"
}

module "stats_logs_forwarder" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.5.0"

  function_name = "${var.prefix}-tracis-ai-stats-logs-forwarder"
  architectures = ["arm64"]
  runtime       = "python3.14"
  handler       = "app.lambda_handler"
  memory_size   = 256
  timeout       = 30

  environment_variables = {
    STATISTICS_LOGS_ENDPOINT = var.statistics_logs_endpoint
  }

  create_package         = false
  local_existing_package = data.archive_file.stats_logs_forwarder.output_path

  role_name                         = "${var.prefix}-tracis-ai-stats-logs-forwarder-role"
  cloudwatch_logs_retention_in_days = 14

  publish = true
}

resource "aws_cloudwatch_log_group" "statistics" {
  name              = local.statistics_log_group_name
  retention_in_days = 1
}

data "aws_iam_policy_document" "stats_logs_forwarder_invocation" {
  statement {
    sid    = "AllowStatisticsLogDelivery"
    effect = "Allow"

    actions = ["lambda:InvokeFunction"]
    resources = [
      "${module.stats_logs_forwarder.lambda_function_arn}",
      "${module.stats_logs_forwarder.lambda_function_arn}:*",
    ]

    principals {
      type = "Service"
      identifiers = [
        "logs.amazonaws.com",
        "logs.${data.aws_region.current.region}.amazonaws.com",
      ]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "${aws_cloudwatch_log_group.statistics.arn}:*",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values = [
        "${data.aws_caller_identity.current.account_id}",
      ]
    }
  }

  statement {
    sid    = "DenyUnexpectedServicePrincipal"
    effect = "Deny"

    actions = ["lambda:InvokeFunction"]
    resources = [
      "${module.stats_logs_forwarder.lambda_function_arn}",
      "${module.stats_logs_forwarder.lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ForAllValues:StringNotEquals"
      variable = "aws:PrincipalServiceNamesList"
      values = [
        "logs.amazonaws.com",
        "logs.${data.aws_region.current.region}.amazonaws.com",
      ]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalServiceName"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid    = "DenyUnexpectedSourceArn"
    effect = "Deny"

    actions = ["lambda:InvokeFunction"]
    resources = [
      "${module.stats_logs_forwarder.lambda_function_arn}",
      "${module.stats_logs_forwarder.lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotLike"
      variable = "aws:SourceArn"
      values = [
        "${aws_cloudwatch_log_group.statistics.arn}:*",
      ]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalServiceName"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid    = "DenyUnexpectedSourceAccount"
    effect = "Deny"

    actions = ["lambda:InvokeFunction"]
    resources = [
      "${module.stats_logs_forwarder.lambda_function_arn}",
      "${module.stats_logs_forwarder.lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceAccount"
      values = [
        "${data.aws_caller_identity.current.account_id}",
      ]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalServiceName"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid    = "DenyFunctionUrl"
    effect = "Deny"

    actions = ["lambda:InvokeFunctionUrl"]
    resources = [
      "${module.stats_logs_forwarder.lambda_function_arn}",
      "${module.stats_logs_forwarder.lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_lambda_resource_policy" "stats_logs_forwarder_invocation" {
  resource_arn = module.stats_logs_forwarder.lambda_function_arn
  policy       = data.aws_iam_policy_document.stats_logs_forwarder_invocation.json
}

resource "aws_cloudwatch_log_subscription_filter" "statistics" {
  name            = "${var.prefix}-tracis-ai-statistics-logs"
  log_group_name  = aws_cloudwatch_log_group.statistics.name
  filter_pattern  = "{ $.transfer_to = \"BTM\" }"
  destination_arn = module.stats_logs_forwarder.lambda_function_arn

  depends_on = [
    aws_lambda_resource_policy.stats_logs_forwarder_invocation,
  ]
}
