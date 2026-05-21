data "archive_file" "lambda_zip" {
  for_each = local.functions

  type        = "zip"
  source_dir  = "${path.module}/src/lambda/${each.key}/"
  output_path = "${path.root}/archive/slack_receiver_v3/${each.key}-function.zip"
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "lambda_powertools_layer" {
  name           = "${var.prefix}-lambda-powertools-python-layer-v3-python314-arm64"
  application_id = "arn:aws:serverlessrepo:eu-west-1:057560766410:applications/aws-lambda-powertools-python-layer-v3-python314-arm64"
  # https://serverlessrepo.aws.amazon.com/applications/eu-west-1/057560766410/aws-lambda-powertools-python-layer-v3-python314-arm64

  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
  ]

  tags = {
    Name = "${var.prefix}-lambda-powertools-python-layer-v3-python314-arm64"
  }
}

module "lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.5.0"

  for_each = local.functions

  function_name = local.function_names[each.key]

  architectures         = ["arm64"]
  runtime               = "python3.14"
  handler               = each.value.handler
  memory_size           = each.value.memory_size
  timeout               = each.value.timeout
  environment_variables = each.value.env_vars

  create_package         = false
  local_existing_package = data.archive_file.lambda_zip[each.key].output_path

  layers = [
    aws_serverlessapplicationrepository_cloudformation_stack.lambda_powertools_layer.outputs["LayerVersionArn"],
  ]

  role_name                = "${var.prefix}-tracis-${each.key}-function-role"
  attach_policy_statements = true
  policy_name              = "${each.key}-function"
  policy_statements        = each.value.policy_statements

  cloudwatch_logs_retention_in_days = 14

  tags = {
    Name = local.function_names[each.key]
  }
}

resource "aws_lambda_permission" "auth_from_api" {
  action        = "lambda:InvokeFunction"
  function_name = module.lambda["slack-auth"].lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway.api_execution_arn}/*"
}

data "aws_iam_policy_document" "invoke_enqueue_func" {
  statement {
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = [
      module.lambda["enqueue"].lambda_function_arn,
    ]
  }
}

resource "aws_iam_role_policy" "auth_invoke_enqueue_func" {
  name   = "enqueue-function-invoke-enqueue-func"
  role   = module.lambda["slack-auth"].lambda_role_name
  policy = data.aws_iam_policy_document.invoke_enqueue_func.json
}
