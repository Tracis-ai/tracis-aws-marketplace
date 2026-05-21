variable "prefix" {
  description = "Prefix for resources"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS"
  type        = list(string)
}

variable "ecs_service_desired_count" {
  description = "Desired count for ECS service"
  type        = number
  default     = 1
}

variable "enable_container_insights" {
  description = "Whether to enable container insights for ECS"
  type        = bool
  default     = false
}

variable "use_fargate_spot" {
  description = "Use Fargate Spot for ECS"
  type        = bool
  default     = false
}

variable "container_image_url" {
  description = "Container image URL for agent"
  type        = string
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

variable "slack_secret_arn" {
  description = "ARN of Secret for Slack credentials"
  type        = string
}

variable "mysql_connection" {
  description = "MySQL connection parameters"
  type = object({
    host                  = string
    port                  = optional(number, 3306)
    db_name               = string
    db_security_group_ids = list(string)
    secret_arn            = string
  })
}
