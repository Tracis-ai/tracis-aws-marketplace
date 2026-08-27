variable "prefix" {
  description = "Prefix for resources"
  type        = string
  nullable    = false
}

variable "subnet_ids" {
  description = "Subnet IDs for AgentCore Runtime VPC connectivity"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) > 0
    error_message = "At least one subnet ID is required."
  }
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

variable "mysql_connection" {
  description = "MySQL connection parameters"
  type = object({
    enabled               = optional(bool, true)
    host                  = optional(string, "")
    port                  = optional(number, 3306)
    db_name               = optional(string, "")
    db_security_group_ids = optional(list(string), [])
    secret_arn            = optional(string, "")
  })

  validation {
    condition = (
      !var.mysql_connection.enabled
      || (
        trimspace(var.mysql_connection.host) != ""
        && trimspace(var.mysql_connection.db_name) != ""
        && length(var.mysql_connection.db_security_group_ids) > 0
        && trimspace(var.mysql_connection.secret_arn) != ""
      )
    )
    error_message = "mysql_connection host, db_name, db_security_group_ids, and secret_arn are required when mysql_connection.enabled is true."
  }

  validation {
    condition = (
      !var.mysql_connection.enabled
      || (var.mysql_connection.port >= 1 && var.mysql_connection.port <= 65535)
    )
    error_message = "mysql_connection.port must be between 1 and 65535 when mysql_connection.enabled is true."
  }
}
