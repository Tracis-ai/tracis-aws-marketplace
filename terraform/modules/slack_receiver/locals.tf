locals {
  api_routes = {
    "slack" = {
      method = "POST"
      path   = "/slack"
      integration = {
        type                   = "AWS_PROXY"
        uri                    = module.lambda["slack-auth"].lambda_function_invoke_arn
        payload_format_version = "2.0"
        timeout_milliseconds   = 3000
      }
    }
  }

  function_keys = [
    "slack-auth",
    "enqueue",
  ]

  function_names = {
    for key in local.function_keys :
    key => "${var.prefix}-tracis-${key}-function"
  }

  functions = {
    "slack-auth" = {
      handler     = "app.lambda_handler"
      memory_size = 128
      timeout     = 3
      env_vars = {
        SLACK_SECRET_ARN      = var.slack_secret_arn,
        ENQUEUE_FUNCTION_NAME = local.function_names["enqueue"],
      }
      policy_statements = {
        "get-secret" = {
          actions = [
            "secretsmanager:GetSecretValue",
          ]
          resources = [
            var.slack_secret_arn,
          ]
        },
      }
    }
    "enqueue" = {
      handler     = "app.lambda_handler"
      memory_size = 128
      timeout     = 10
      env_vars = {
        SLACK_SECRET_ARN = var.slack_secret_arn,
        SQS_QUEUE_URL    = var.sqs_queue.url,
      }
      policy_statements = {
        "get-secret" = {
          actions = [
            "secretsmanager:GetSecretValue",
          ]
          resources = [var.slack_secret_arn]
        },
        "enqueue" = {
          actions = [
            "sqs:SendMessage",
          ]
          resources = [var.sqs_queue.arn]
        }
      }
    }
  }
}
