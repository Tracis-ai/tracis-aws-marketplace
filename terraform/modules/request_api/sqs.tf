locals {
  queues = {
    request = {
      message_retention_seconds  = 30 * 60 #30 minutes
      visibility_timeout_seconds = 7 * 60  #7 minutes
    }
    response = {
      message_retention_seconds  = 30 * 60 #30 minutes
      visibility_timeout_seconds = 3 * 60  #3 minutes
    }
  }

  queue_producer_role_arns = {
    request = [
      for key, function in local.receiver_functions : module.lambda[key].lambda_role_arn
      if function.type == "enqueue"
    ]
    response = [
      module.lambda["invoker"].lambda_role_arn,
    ]
  }

  queue_consumer_role_arns = {
    request  = module.lambda["invoker"].lambda_role_arn
    response = module.lambda["dispatcher"].lambda_role_arn
  }
}

module "sqs" {
  for_each = local.queues

  source  = "terraform-aws-modules/sqs/aws"
  version = "5.2.2"

  name                        = "${var.prefix}-tracis-ai-${each.key}-queue"
  fifo_queue                  = true
  content_based_deduplication = true
  message_retention_seconds   = each.value.message_retention_seconds
  visibility_timeout_seconds  = each.value.visibility_timeout_seconds
}

data "aws_iam_policy_document" "sqs_massage_access" {
  for_each = local.queues

  statement {
    sid       = "DenyOutsideAccount"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [module.sqs[each.key].queue_arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "BoolIfExists"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }
  }

  statement {
    sid       = "DenyServiceFromOutsideAccount"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [module.sqs[each.key].queue_arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:PrincipalIsAWSService"
      values   = ["true"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "DenyUnexpectedProducer"
    effect    = "Deny"
    actions   = ["sqs:SendMessage"]
    resources = [module.sqs[each.key].queue_arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = local.queue_producer_role_arns[each.key]
    }
  }

  statement {
    sid    = "DenyUnexpectedConsumer"
    effect = "Deny"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [module.sqs[each.key].queue_arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = [local.queue_consumer_role_arns[each.key]]
    }
  }
}

resource "aws_sqs_queue_policy" "sqs_massage_access" {
  for_each = local.queues

  queue_url = module.sqs[each.key].queue_url
  policy    = data.aws_iam_policy_document.sqs_massage_access[each.key].json
}
