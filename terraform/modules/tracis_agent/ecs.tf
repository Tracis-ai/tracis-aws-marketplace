module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "7.3.0"

  cluster_name = "${var.prefix}-tracis-agent-cluster"

  cluster_capacity_providers = [
    for _, strategy in local.capacity_provider_strategy :
    strategy.capacity_provider
  ]

  cluster_setting = [
    {
      name  = "containerInsights"
      value = var.enable_container_insights ? "enabled" : "disabled"
    },
  ]

  cluster_tags = {
    "Name" = "${var.prefix}-tracis-agent-cluster"
  }

  services = {
    "tracis" = {
      name = local.service_name

      desired_count            = var.ecs_service_desired_count
      autoscaling_min_capacity = var.ecs_service_desired_count
      autoscaling_max_capacity = var.ecs_service_desired_count

      capacity_provider_strategy = local.capacity_provider_strategy

      deployment_circuit_breaker = {
        enable   = true
        rollback = true
      }

      subnet_ids          = var.subnet_ids
      security_group_name = "${var.prefix}-tracis-agent-sg"
      security_group_egress_rules = {
        all = {
          description = "Allow all outbound traffic"
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }

      runtime_platform = {
        cpu_architecture        = "ARM64"
        operating_system_family = "LINUX"
      }

      volume = {
        "tmp" = {}
      }

      task_exec_iam_role_name            = "${var.prefix}-tracis-agent-task-exec-role"
      task_exec_iam_role_use_name_prefix = false
      task_exec_secret_arns              = [var.slack_secret_arn]
      task_exec_iam_role_tags = {
        Name = "${var.prefix}-tracis-agent-task-exec-role"
      }

      tasks_iam_role_name            = "${var.prefix}-tracis-agent-tasks-role"
      tasks_iam_role_use_name_prefix = false
      tasks_iam_role_statements      = local.tasks_role_statements
      tasks_iam_role_tags = {
        Name = "${var.prefix}-tracis-agent-tasks-role"
      }

      service_tags = {
        Name = local.service_name
      }

      container_definitions = {
        for container_name, container_config in local.containers :
        container_name => {
          essential = true
          image     = container_config.image
          cpu       = container_config.cpu
          memory    = container_config.memory
          environment = [
            for env_key, env_value in container_config.env_vars : {
              name  = env_key
              value = env_value
            }
          ]
          secrets                                = container_config.secrets
          cloudwatch_log_group_name              = "/aws/ecs/${local.service_name}/${container_name}"
          cloudwatch_log_group_retention_in_days = 14
          logConfiguration                       = container_config.log_configuration
          firelensConfiguration                  = container_config.firelens_configuration
          mountPoints                            = container_config.mount_points
          user                                   = container_config.user
          healthCheck                            = container_config.health_check
        }
      }
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_tracis_agent" {
  for_each          = toset(var.mysql_connection.db_security_group_ids)
  security_group_id = each.value

  ip_protocol                  = "tcp"
  from_port                    = var.mysql_connection.port
  to_port                      = var.mysql_connection.port
  referenced_security_group_id = module.ecs.services["tracis"].security_group_id
  description                  = "Allow inbound from Tracis Agent"
}
