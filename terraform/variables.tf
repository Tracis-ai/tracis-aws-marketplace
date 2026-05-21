variable "ecs_service_desired_count" {
  description = "Desired count for ECS service"
  type        = number
}

variable "prefix" {
  description = "Prefix for resources"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS service"
  type        = string
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

variable "slack_secret_arn" {
  description = "ARN of Secret for Slack credentials"
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
  description = "ECR image URL for Tracis agent"
  type        = string
}

variable "enable_fargate_spot" {
  description = "Whether to use Fargate Spot for cost optimization"
  type        = bool
}
