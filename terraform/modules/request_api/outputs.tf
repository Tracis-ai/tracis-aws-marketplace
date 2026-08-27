output "request_api_urls" {
  value = {
    for key, receiver in local.request_receivers :
    key => "${module.api_gateway.api_endpoint}${receiver.path}"
  }
}
