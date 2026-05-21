output "slack_receive_api_url" {
  value = "${module.api_gateway.api_endpoint}${lookup(local.api_routes["slack"], "path", "")}"
}
