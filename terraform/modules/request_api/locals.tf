locals {
  request_receivers = {
    "slack" = {
      path                     = "/slack"
      api_timeout_milliseconds = 3000
      function_timeout_seconds = {
        auth    = 3
        enqueue = 10
      }
    },
    "chatwork" = {
      path                     = "/chatwork"
      api_timeout_milliseconds = 3000
      function_timeout_seconds = {
        auth    = 10
        enqueue = 10
      }
    }
  }

  receiver_functions = merge(
    [
      for key, receiver in local.request_receivers : {
        for function_type in ["auth", "enqueue"] :
        "${key}-${function_type}" => {
          platform   = key
          type       = function_type
          source_dir = "${path.module}/src/lambda/${key}/${function_type}/"
          name       = "${var.prefix}-tracis-ai-${key}-${function_type}-function"
          secret_arn = var.chat_tools_secret_arn
          timeout    = receiver.function_timeout_seconds[function_type]
        }
      }
    ]...
  )

  invoker_function = {
    "invoker" = {
      platform   = "invoker"
      type       = "invoker"
      source_dir = "${path.module}/src/lambda/invoker/"
      name       = "${var.prefix}-tracis-ai-agent-invoker-function"
      secret_arn = null
      timeout    = 360
    }
  }

  dispatcher_function = {
    "dispatcher" = {
      platform   = "dispatcher"
      type       = "dispatcher"
      source_dir = "${path.module}/src/lambda/dispatcher/"
      name       = "${var.prefix}-tracis-ai-response-dispatcher-function"
      secret_arn = var.chat_tools_secret_arn
      timeout    = 60
    }
  }

  lambda_functions = merge(
    local.receiver_functions,
    local.invoker_function,
    local.dispatcher_function,
  )
}
