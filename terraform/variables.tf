variable "prefix" {
  description = "Prefix for resources"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS service"
  type        = string
}

variable "enabled_db_types" {
  description = "Database type to connect. Only mysql is currently supported."
  type        = string

  validation {
    condition     = contains(["", "mysql"], trimspace(var.enabled_db_types))
    error_message = "enabled_db_types must be empty or mysql."
  }
}

variable "mysql_endpoint" {
  description = "Endpoint of MySQL database for log analysis"
  type        = string
}

variable "mysql_port" {
  description = "Port of MySQL database for log analysis"
  type        = number
}

variable "mysql_db_name" {
  description = "Database name for log analysis"
  type        = string
}

variable "mysql_security_group_ids" {
  description = "List of security group IDs for RDS instance"
  type        = string
}


variable "mysql_secret_arn" {
  description = "ARN of Secret for MySQL credentials"
  type        = string
}

variable "chat_tools_secret_arn" {
  description = "ARN of Secret for chat tool credentials"
  type        = string
}

variable "bedrock_model_id" {
  description = "Model ID of Bedrock for Agents"
  type        = string
}

variable "max_tokens" {
  description = "Max tokens for Bedrock model"
  type        = number
}

variable "agent_image_url" {
  description = "ECR image URL for TracisAI agent"
  type        = string
}

variable "pii_output_entity_types" {
  description = "Comma-separated PII entity types to anonymize in agent output"
  type        = string
  default     = ""
}
