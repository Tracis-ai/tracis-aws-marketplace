module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "5.2.1"

  name                        = "${var.prefix}-log-analyze-request-queue"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = local.agent_process_timeout_seconds + 60
}
