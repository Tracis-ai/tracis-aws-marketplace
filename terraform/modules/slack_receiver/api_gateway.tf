module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "6.1.0"

  name          = "${var.prefix}-slack-receive-api"
  protocol_type = "HTTP"

  routes = {
    for route_key, route_config in local.api_routes :
    "${route_config.method} ${route_config.path}" => {
      integration = lookup(route_config, "integration", null)
    }
  }

  create_domain_name = false

  tags = {
    Name = "${var.prefix}-slack-receive-api"
  }
}
