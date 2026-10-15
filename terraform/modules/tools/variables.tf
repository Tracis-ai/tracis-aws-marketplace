variable "prefix" {
  description = "Prefix for resource names"
  type        = string
  nullable    = false
}

variable "runtime_role" {
  description = "TracisAI AgentCore Runtime execution role"
  type = object({
    arn  = string
    name = string
  })
  nullable = false
}

variable "lambda_subnet_ids" {
  description = "Subnet IDs for Tool Lambda VPC connectivity"
  type        = list(string)
}

variable "mysql_connection" {
  description = "Fixed MySQL connection parameters for the MySQL Tool Lambda"
  type = object({
    enabled               = bool
    host                  = optional(string)
    port                  = optional(number, 3306)
    db_name               = optional(string)
    db_security_group_ids = optional(list(string), [])
    secret_arn            = optional(string)
  })
  default = {
    enabled = true
  }

  validation {
    condition = !var.mysql_connection.enabled ? true : (
      try(trimspace(var.mysql_connection.host), "") != ""
      && try(trimspace(var.mysql_connection.db_name), "") != ""
      && length(var.mysql_connection.db_security_group_ids) > 0
      && try(trimspace(var.mysql_connection.secret_arn), "") != ""
      && floor(var.mysql_connection.port) == var.mysql_connection.port
      && var.mysql_connection.port >= 1
      && var.mysql_connection.port <= 65535
    )
    error_message = "Enabled mysql_connection parameters must be complete and valid."
  }
}

variable "container_image_urls" {
  description = "Container image URLs keyed by tool name"
  type = object({
    mysql = optional(string)
  })

  validation {
    condition = alltrue([
      for image_url in values(var.container_image_urls) :
      image_url == null ? true : trimspace(image_url) != ""
    ])
    error_message = "container_image_urls values must be null or non-empty strings."
  }
}
