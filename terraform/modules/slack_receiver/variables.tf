variable "prefix" {
  description = "Prefix for resources"
  type        = string
}

variable "slack_secret_arn" {
  description = "ARN of Secret for Slack credentials"
  type        = string
}

variable "sqs_queue" {
  description = "URL and ARN of the SQS queue for Agent requests"
  type = object({
    arn = string
    url = string
  })
}
