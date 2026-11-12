locals {
  root_resources = {
    "api" = {
      parent_resource_key = null
      path_part           = "api"
      methods             = []
    }
  }
  child_resources = {
    "proxy" = {
      parent_resource_key = "api"
      path_part           = "{proxy+}"
      methods = [
        {
          http_method   = "GET"
          authorization = "NONE"
        },
        {
          http_method   = "POST"
          authorization = "NONE"
        },
      ]
    }
    "setup-links" = {
      parent_resource_key = "api"
      path_part           = "setup-links"
      methods = [
        {
          http_method   = "POST"
          authorization = "AWS_IAM"
        },
      ]
    }
  }

  all_resources = merge(
    local.root_resources,
    local.child_resources,
  )
  method_definitions = merge(
    [
      for resource_key, resource in local.all_resources :
      {
        for method in resource.methods :
        "${resource_key}-${lower(method.http_method)}" => {
          resource_key  = resource_key
          http_method   = method.http_method
          authorization = method.authorization
          integration = {
            type                 = "AWS_PROXY"
            http_method          = "POST"
            integration_uri      = module.setup_api_function.lambda_function_invoke_arn
            timeout_milliseconds = 29000
          }
        }
      }
    ]...
  )

  oidc_chat_tools = [
    "slack",
  ]
  oidc_redirect_paths = {
    for chat_tool in local.oidc_chat_tools :
    chat_tool => "${local.root_resources["api"].path_part}/oidc/${chat_tool}/callback"
  }
}

check "unique_api_resource_keys" {
  assert {
    condition = length(
      setintersection(
        toset(keys(local.root_resources)),
        toset(keys(local.child_resources)),
      )
    ) == 0
    error_message = "API resource keys must be unique across root_resources and child_resources"
  }
}

resource "aws_api_gateway_rest_api" "this" {
  name                         = "${var.prefix}-tracis-ai-setup-api"
  description                  = "TracisAI Setup API"
  disable_execute_api_endpoint = false

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "root" {
  for_each = local.root_resources

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.value.path_part
}

resource "aws_api_gateway_resource" "child" {
  for_each = local.child_resources

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.root[each.value.parent_resource_key].id
  path_part   = each.value.path_part
}

locals {
  api_resource_ids = merge(
    { for key, resource in aws_api_gateway_resource.root : key => resource.id },
    { for key, resource in aws_api_gateway_resource.child : key => resource.id },
  )
}

resource "aws_api_gateway_method" "this" {
  for_each = local.method_definitions

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = local.api_resource_ids[each.value.resource_key]
  http_method   = each.value.http_method
  authorization = each.value.authorization
}

resource "aws_api_gateway_integration" "this" {
  for_each = local.method_definitions

  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = local.api_resource_ids[each.value.resource_key]
  http_method             = aws_api_gateway_method.this[each.key].http_method
  integration_http_method = each.value.integration.http_method
  type                    = each.value.integration.type
  uri                     = each.value.integration.integration_uri
  timeout_milliseconds    = each.value.integration.timeout_milliseconds
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers = {
    "redeployment" = sha1(jsonencode({
      resources = merge(
        aws_api_gateway_resource.root,
        aws_api_gateway_resource.child,
      )
      methods      = aws_api_gateway_method.this
      integrations = aws_api_gateway_integration.this
    }))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = "setup"
}

resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    data_trace_enabled     = false
    logging_level          = "OFF"
    metrics_enabled        = true
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }
}

data "aws_iam_policy_document" "invoke_setup_links" {
  statement {
    actions = ["execute-api:Invoke"]
    resources = [
      "${aws_api_gateway_rest_api.this.execution_arn}/${aws_api_gateway_stage.this.stage_name}/POST/api/setup-links",
    ]
  }
}

resource "aws_iam_role_policy" "invoke_setup_links" {
  name   = "invoke-setup-links"
  role   = var.invoker_function_role_name
  policy = data.aws_iam_policy_document.invoke_setup_links.json
}
