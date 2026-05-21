module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "5.2.1"

  name                        = "${var.prefix}-tracis-request-queue"
  fifo_queue                  = true
  content_based_deduplication = true
  message_retention_seconds   = 30 * 60 # 30 minutes
  visibility_timeout_seconds  = local.agent_process_timeout_seconds + 60
}
