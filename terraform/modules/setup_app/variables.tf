variable "prefix" {
  description = "Prefix for Setup application resources"
  type        = string
}

variable "invoker_function_role_name" {
  description = "Execution role name for Agent invoker function"
  type        = string
  nullable    = false
}

variable "chat_tools_secret_arn" {
  description = "ARN of the shared Secret for chat tool credentials"
  type        = string
  nullable    = false
}

variable "setup_api_image_url" {
  description = "Container image URL shared with the Agent runtime"
  type        = string
  nullable    = false
}

variable "schema_reader_image_urls" {
  description = "Container image URLs for schema readers keyed by tool name"
  type = object({
    mysql = optional(string)
  })
  default = {}
}

variable "enabled_tools" {
  description = "Enabled tool names supplied by the tools module"
  type        = set(string)
  default     = []
  nullable    = false
}

variable "lambda_subnet_ids" {
  description = "Subnet IDs for schema reader Lambda VPC connectivity"
  type        = list(string)
  default     = []
}

variable "tool_sg_ids" {
  description = "Existing Tool Lambda security group IDs keyed by tool name"
  type        = map(string)
  default     = {}
}

variable "mysql_connection" {
  description = "MySQL connection configuration shared with the MySQL Tool Lambda"
  type = object({
    enabled    = bool
    host       = optional(string)
    port       = optional(number, 3306)
    db_name    = optional(string)
    secret_arn = optional(string)
  })
  default = {
    enabled = false
  }
}

variable "knowledge_bases" {
  description = "Fixed Knowledge Base ingestion destination for Setup API"
  type = object({
    arn            = string
    id             = string
    data_source_id = string
    data_source_bucket = object({
      arn                = string
      name               = string
      encryption_key_arn = string
    })
  })
  default  = null
  nullable = true
}

variable "context_generation_config" {
  description = "Converse model and output token limit for context generation"
  type = object({
    model_id   = optional(string, "global.anthropic.claude-sonnet-4-6")
    max_tokens = optional(number, 2048)
  })
  default  = {}
  nullable = false

  validation {
    condition = (
      length(var.context_generation_config.model_id) >= 1 &&
      length(var.context_generation_config.model_id) <= 2048 &&
      !can(regex("[[:space:]]", var.context_generation_config.model_id))
    )
    error_message = "context_generation_config.model_id must contain 1 to 2048 characters without whitespace."
  }

  validation {
    condition = (
      var.context_generation_config.max_tokens >= 1 &&
      var.context_generation_config.max_tokens <= 16384 &&
      floor(var.context_generation_config.max_tokens) == var.context_generation_config.max_tokens
    )
    error_message = "context_generation_config.max_tokens must be an integer between 1 and 16384."
  }
}
