data "aws_subnet" "this" {
  region = data.aws_region.current.region
  id     = element(var.subnet_ids, 0)
}

resource "aws_service_discovery_private_dns_namespace" "this" {
  name = local.svc_discovery.namespace
  vpc  = data.aws_subnet.this.vpc_id
}

resource "aws_service_discovery_service" "this" {
  for_each = local.svc_discovery.targets

  name = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      type = "A"
      ttl  = 30
    }
  }
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "7.3.0"

  depends_on = [aws_s3_object.firelens_config]

  # ECS Cluster Configuration
  cluster_name = "${var.prefix}-log-analyze-agent-cluster"

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
    "Name" = "${var.prefix}-log-analyze-agent-cluster"
  }

  # ECS Service Configuration
  services = {
    for svc_key, svc_config in local.services : svc_key => {
      name = local.service_names[svc_key]

      capacity_provider_strategy = local.capacity_provider_strategy

      deployment_circuit_breaker = {
        enable   = true
        rollback = true
      }

      service_registries = contains(keys(local.svc_discovery.targets), svc_key) ? {
        registry_arn = aws_service_discovery_service.this[svc_key].arn
      } : null

      subnet_ids          = var.subnet_ids
      security_group_name = "${var.prefix}-log-analyze-${svc_key}-sg"
      security_group_egress_rules = {
        all = {
          description = "Allow all outbound traffic"
          ip_protocol = "-1"
          cidr_ipv4   = "0.0.0.0/0"
        }
      }

      task_exec_iam_role_name            = "${var.prefix}-log-analyze-${svc_key}-task-exec-role"
      task_exec_iam_role_use_name_prefix = false
      task_exec_secret_arns              = lookup(svc_config, "task_exec_secret_arns", null)
      task_exec_iam_role_tags = {
        Name = "${var.prefix}-log-analyze-${svc_key}-task-exec-role"
      }

      tasks_iam_role_name            = "${var.prefix}-log-analyze-${svc_key}-tasks-role"
      tasks_iam_role_use_name_prefix = false
      tasks_iam_role_statements = concat(
        local.common_tasks_role_statements,
        lookup(svc_config, "tasks_role_statements", []),
      )
      tasks_iam_role_tags = {
        Name = "${var.prefix}-log-analyze-${svc_key}-tasks-role"
      }

      desired_count            = var.ecs_service_desired_count
      autoscaling_min_capacity = var.ecs_service_desired_count
      autoscaling_max_capacity = var.ecs_service_desired_count

      runtime_platform = {
        cpu_architecture        = "ARM64"
        operating_system_family = "LINUX"
      }

      volume = contains(keys(svc_config.containers), "log-router") ? {
        "tmp" = {}
      } : {}

      # Container definitions
      container_definitions = {
        for container_key, container_config in svc_config.containers : container_key => {
          essential = true
          cpu       = container_config.cpu
          memory    = container_config.memory
          image = (
            container_key == "log-router"
            ? "public.ecr.aws/aws-observability/aws-for-fluent-bit:init-latest"
            : var.container_image_urls[svc_key][container_key]
          )
          command = lookup(container_config, "command", null)
          environment = concat([
            for env_key, env_value in lookup(container_config, "env_vars", {}) : {
              name  = env_key
              value = env_value
            }
            ],
            container_key == "log-router" ? [
              {
                name  = "CW_LOG_GROUP_NAME"
                value = local.log_group_names[svc_key]["agent"]
              },
            ] : []
          )
          secrets = lookup(container_config, "secrets", null)
          portMappings = can(local.svc_discovery.targets[svc_key].port) && container_key == "agent" ? [
            {
              name          = svc_key
              containerPort = local.svc_discovery.targets[svc_key].port
              protocol      = "tcp"
            }
          ] : null
          cloudwatch_log_group_name              = local.log_group_names[svc_key][container_key]
          cloudwatch_log_group_retention_in_days = 14
          logConfiguration = (
            container_key == "agent" &&
            contains(keys(svc_config.containers), "log-router")
            ) ? {
            logDriver = "awsfirelens"
            options = {
              log-driver-buffer-limit = "10485760" # 10MB buffer limit for firelens
            }
            } : {
            logDriver = "awslogs"
            options = {
              awslogs-group         = local.log_group_names[svc_key][container_key]
              awslogs-region        = data.aws_region.current.region
              awslogs-stream-prefix = "/ecs"
            }
          }
          firelensConfiguration = container_key == "log-router" ? {
            type = "fluentbit"
            options = {
              enable-ecs-log-metadata = "true"
            }
          } : null
          mountPoints = container_key == "log-router" ? [
            {
              sourceVolume  = "tmp"
              containerPath = "/tmp"
              readOnly      = false
            },
          ] : null
          user = container_key == "log-router" ? "0" : null
          healthCheck = container_key == "mcp" ? {
            command = [
              "CMD-SHELL",
              "python -c \"import socket; socket.create_connection(('127.0.0.1',8000),3).close()\" || exit 1",
            ]
            interval = 8
            timeout  = 5
            retries  = 3
            } : container_key == "log-router" ? {
            command = [
              "CMD-SHELL",
              "curl -f http://127.0.0.1:2020/api/v1/health || exit 1",
            ]
            interval = 30
            timeout  = 5
            retries  = 3
          } : null
          dependsOn = (
            container_key == "agent" &&
            contains(keys(svc_config.containers), "mcp")
            ) ? [
            {
              containerName = "mcp"
              condition     = "HEALTHY"
            }
          ] : null
        }
      }

      service_tags = {
        Name = local.service_names[svc_key]
      }
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "tool_agent_from_orchestrator" {
  for_each = {
    for svc_key, target in local.svc_discovery.targets : svc_key => target.port
  }
  security_group_id = module.ecs.services[each.key].security_group_id

  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  referenced_security_group_id = module.ecs.services["orchestrator"].security_group_id
  description                  = "Allow inbound traffic from Log Analyze Orchestrator Agent"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_mysql_agent" {
  for_each          = toset(var.mysql_connection.db_security_group_ids)
  security_group_id = each.value

  ip_protocol                  = "tcp"
  from_port                    = var.mysql_connection.port
  to_port                      = var.mysql_connection.port
  referenced_security_group_id = module.ecs.services["mysql-search"].security_group_id
  description                  = "Allow inbound from Log Analyze MySQL Search Agent"
}
