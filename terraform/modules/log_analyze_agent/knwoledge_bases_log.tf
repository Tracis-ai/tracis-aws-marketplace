resource "aws_cloudwatch_log_group" "kb" {
  name              = "/aws/vendedlogs/bedrock/knowledge-base/APPLICATION_LOGS/${aws_bedrockagent_knowledge_base.this.id}"
  retention_in_days = 14
}

# https://docs.aws.amazon.com/ja_jp/bedrock/latest/userguide/knowledge-bases-logging.html
resource "aws_cloudwatch_log_delivery_source" "kb" {
  name         = "${aws_bedrockagent_knowledge_base.this.name}-log-delivery-source"
  log_type     = "APPLICATION_LOGS"
  resource_arn = aws_bedrockagent_knowledge_base.this.arn
}

resource "aws_cloudwatch_log_delivery_destination" "kb" {
  name = "${aws_bedrockagent_knowledge_base.this.name}-log-delivery-destination"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.kb.arn
  }
}

resource "aws_cloudwatch_log_delivery" "kb" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.kb.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.kb.arn
}

# https://docs.aws.amazon.com/ja_jp/AmazonCloudWatch/latest/logs/AWS-logs-infrastructure-V2-CloudWatchLogs.html
data "aws_iam_policy_document" "kb_logging" {
  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "${aws_cloudwatch_log_group.kb.arn}:log-stream:*"
    ]

    principals {
      type = "Service"
      identifiers = [
        "delivery.logs.amazonaws.com",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values = [
        data.aws_caller_identity.current.account_id,
      ]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*",
      ]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "kb_logging" {
  policy_name     = "${aws_bedrockagent_knowledge_base.this.name}-logging-policy"
  policy_document = data.aws_iam_policy_document.kb_logging.json
}
