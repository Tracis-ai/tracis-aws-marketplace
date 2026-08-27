module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "6.1.0"

  name          = "${var.prefix}-tracis-ai-request-api"
  protocol_type = "HTTP"

  routes = {
    for key, receiver in local.request_receivers :
    "POST ${receiver.path}" => {
      integration = {
        type                   = "AWS_PROXY"
        uri                    = module.lambda["${key}-auth"].lambda_function_invoke_arn
        payload_format_version = "2.0"
        timeout_milliseconds   = receiver.api_timeout_milliseconds
      }
    }
  }

  create_domain_name = false

  tags = {
    Name = "${var.prefix}-tracis-ai-request-api"
  }
}
