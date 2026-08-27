locals {
  queues = {
    request = {
      message_retention_seconds  = 30 * 60 #30 minutes
      visibility_timeout_seconds = 7 * 60  #7 minutes
    }
    response = {
      message_retention_seconds  = 30 * 60 #30 minutes
      visibility_timeout_seconds = 3 * 60  #3 minutes
    }
  }
}

module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "5.2.2"

  for_each = local.queues

  name                        = "${var.prefix}-tracis-ai-${each.key}-queue"
  fifo_queue                  = true
  content_based_deduplication = true
  message_retention_seconds   = each.value.message_retention_seconds
  visibility_timeout_seconds  = each.value.visibility_timeout_seconds
}
