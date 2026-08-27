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

resource "aws_lambda_permission" "stats_logs_forwarder" {
  statement_id   = "AllowCloudWatchLogsInvocation"
  action         = "lambda:InvokeFunction"
  function_name  = module.stats_logs_forwarder.lambda_function_name
  principal      = "logs.${data.aws_region.current.region}.amazonaws.com"
  source_arn     = "${aws_cloudwatch_log_group.statistics.arn}:*"
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_cloudwatch_log_group" "statistics" {
  name              = local.statistics_log_group_name
  retention_in_days = 1
}


resource "aws_cloudwatch_log_subscription_filter" "statistics" {
  name            = "${var.prefix}-tracis-ai-statistics-logs"
  log_group_name  = aws_cloudwatch_log_group.statistics.name
  filter_pattern  = "{ $.transfer_to = \"BTM\" }"
  destination_arn = module.stats_logs_forwarder.lambda_function_arn

  depends_on = [aws_lambda_permission.stats_logs_forwarder]
}
