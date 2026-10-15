variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "enabled_tools" {
  description = "Names of tools with configured container image"
  type        = list(string)
}


variable "container_image_urls" {
  description = "Container image URLs keyed by tool name"
  type = object({
    mysql = optional(string)
  })
}

variable "handler" {
  description = "Handler name for container command override"
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "List of subnet IDs for VPC configuration"
  type        = list(string)
}

variable "tool_sg_ids" {
  description = "Security group IDs keyed by VPC associated tool name"
  type        = map(string)
}

variable "mysql_connection" {
  description = "Connection configuration for MySQL tool function"
  type = object({
    enabled    = bool
    host       = optional(string)
    port       = optional(number, 3306)
    db_name    = optional(string)
    secret_arn = optional(string)
  })
}
