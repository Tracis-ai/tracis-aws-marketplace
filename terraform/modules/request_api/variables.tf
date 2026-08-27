variable "prefix" {
  description = "Prefix for resources"
  type        = string
}

variable "chat_tools_secret_arn" {
  description = "ARN of the shared Secret for chat tool credentials"
  type        = string
  nullable    = false
}

variable "agent_invocation_url" {
  description = "URL for invoking the Agent API"
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.agent_invocation_url) != ""
    error_message = "agent_invocation_url must not be empty."
  }
}

variable "agentcore_config" {
  description = "Configuration for AgentCore runtime"
  type = object({
    enabled     = bool
    runtime_arn = optional(string)
  })
  nullable = false

  validation {
    condition = (
      !var.agentcore_config.enabled
      || try(trimspace(var.agentcore_config.runtime_arn) != "", false)
    )
    error_message = "agentcore_config.runtime_arn must be provided when agentcore_config.enabled is true."
  }
}

variable "vpc_config" {
  description = "VPC configuration for ECS runtime"
  type = object({
    enabled        = bool
    agent_sg_id    = optional(string)
    agent_api_port = optional(number)
    subnet_ids     = optional(list(string), [])
  })
  nullable = false

  validation {
    condition = (
      !var.vpc_config.enabled
      || (
        try(trimspace(var.vpc_config.agent_sg_id) != "", false)
        && try(
          var.vpc_config.agent_api_port >= 1
          && var.vpc_config.agent_api_port <= 65535,
          false,
        )
        && length(try(var.vpc_config.subnet_ids, [])) > 0
      )
    )
    error_message = "vpc_config.agent_sg_id, vpc_config.agent_api_port, and vpc_config.subnet_ids must be valid when vpc_config.enabled is true."
  }
}
