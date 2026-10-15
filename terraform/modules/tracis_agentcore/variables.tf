variable "prefix" {
  description = "Prefix for resources"
  type        = string
  nullable    = false
}

variable "container_image_url" {
  description = "Container image URL for AgentCore Runtime"
  type        = string
}

variable "statistics_logs_endpoint" {
  description = "Statistics logs receiver endpoint"
  type        = string
  default     = "https://customer.tracis.ai/v1/logs"

  validation {
    condition     = can(regex("^https://", var.statistics_logs_endpoint))
    error_message = "statistics_logs_endpoint must use HTTPS."
  }
}

variable "model_config" {
  description = "Configuration for the Bedrock model"
  type = object({
    bedrock_model_id       = optional(string)
    max_tokens             = optional(number)
    temperature            = optional(number)
    top_p                  = optional(number)
    enable_guardrail_trace = optional(string)
  })
}

variable "gateway_tools_config" {
  description = "AgentCore Gateway URL and enabled tools"
  type = object({
    enabled_tools = set(string)
    gateway_url   = string
  })
  nullable = false
}

variable "pii_output_entity_types" {
  description = "PII entity types to anonymize in agent output"
  type        = set(string)
  nullable    = false
  default = [
    "ADDRESS",
    "AWS_ACCESS_KEY",
    "AWS_SECRET_KEY",
    "CREDIT_DEBIT_CARD_CVV",
    "CREDIT_DEBIT_CARD_EXPIRY",
    "CREDIT_DEBIT_CARD_NUMBER",
    "EMAIL",
    "NAME",
    "PASSWORD",
    "PHONE",
    "PIN",
    "USERNAME",
  ]
}
