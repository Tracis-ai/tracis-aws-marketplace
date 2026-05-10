data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  capacity_provider_strategy = {
    FARGATE = {
      capacity_provider = "FARGATE"
      weight            = var.use_fargate_spot ? 0 : 1
    }
    FARGATE_SPOT = {
      capacity_provider = "FARGATE_SPOT"
      weight            = var.use_fargate_spot ? 1 : 0
    }
  }

  svc_discovery = {
    namespace = "${var.prefix}-log-analyze.local"
    targets = {
      "cloudwatch-search" = {
        port = 9000
      }
      "mysql-search" = {
        port = 9000
      }
    }
  }

  svc_discovery_urls = {
    for svc_key, target in local.svc_discovery.targets :
    svc_key => "http://${svc_key}.${local.svc_discovery.namespace}:${target.port}"
  }

  service_names = {
    for svc_key in keys(local.services) :
    svc_key => "${var.prefix}-log-analyze-${svc_key}-agent-service"
  }

  log_group_names = {
    for svc_key, svc_config in local.services :
    svc_key => {
      for container_key in keys(svc_config.containers) :
      container_key => "/aws/ecs/${local.service_names[svc_key]}/${container_key}"
    }
  }

  common_tasks_role_statements = [
    {
      sid = "AllowECSTasksDescribe"
      actions = [
        "ecs:DescribeTasks",
      ]
      resources = [
        "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task/${var.prefix}-log-analyze-agent-cluster/*",
      ]
    },
    {
      sid = "AllowModelSubscription"
      actions = [
        "aws-marketplace:ViewSubscriptions",
        "aws-marketplace:Subscribe",
        "aws-marketplace:Unsubscribe",
      ]
      resources = ["*"]
    },
    {
      sid = "AllowBedrockInvoke"
      actions = [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ApplyGuardrail",
        "bedrock:Retrieve",
      ]
      resources = [
        "*"
      ]
    },
  ]

  agent_process_timeout_seconds = 300

  services = {
    "orchestrator" = {
      containers = {
        "agent" = {
          cpu    = 512
          memory = 1024
          env_vars = merge(
            {
              LOG_LEVEL                     = "INFO",
              AGENT_PROCESS_TIMEOUT_SECONDS = tostring(local.agent_process_timeout_seconds),
              SQS_QUEUE_URL                 = module.sqs.queue_url,
              SQS_MAX_RETRY_COUNT           = "5",
              CLOUDWATCH_SEARCH_AGENT_URL   = local.svc_discovery_urls["cloudwatch-search"],
              MYSQL_SEARCH_AGENT_URL        = local.svc_discovery_urls["mysql-search"],
              GUARDRAIL_ID                  = aws_bedrock_guardrail.this.guardrail_id
              GUARDRAIL_VERSION             = aws_bedrock_guardrail_version.this.version
              KNOWLEDGE_BASE_ID             = aws_bedrockagent_knowledge_base.this.id
            },
            {
              for key, value in var.model_configs["orchestrator"] :
              upper(key) => tostring(value) if value != null
            },
          )
          secrets = [
            {
              name      = "SLACK_BOT_TOKEN"
              valueFrom = "${var.slack_secret_arn}:SLACK_BOT_TOKEN::"
            }
          ]
        }
        "log-router" = {
          cpu    = 256
          memory = 512
          env_vars = {
            ACCOUNT_ID               = data.aws_caller_identity.current.account_id
            aws_fluent_bit_init_s3_1 = aws_s3_object.firelens_config.arn
          }
        }
      }
      task_exec_secret_arns = [
        var.slack_secret_arn,
      ]
      tasks_role_statements = [
        {
          sid = "AllowSQSPolling"
          actions = [
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:ChangeMessageVisibility",
          ]
          resources = [module.sqs.queue_arn]
        },
        {
          sid = "AllowCloudWatchLogging"
          actions = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          resources = [
            "*"
          ]
        },
        {
          sid = "AllowFirelensConfigGet"
          actions = [
            "s3:GetBucketLocation",
            "s3:GetObject",
          ]
          resources = [
            module.firelens_config_bucket.s3_bucket_arn,
            aws_s3_object.firelens_config.arn,
          ]
        },
      ]
    }
    "cloudwatch-search" = {
      containers = {
        "agent" = {
          cpu    = 512
          memory = 1024
          env_vars = merge(
            {
              AGENT_TYPE        = "cloudwatch-search"
              AGENT_URL         = local.svc_discovery_urls["cloudwatch-search"],
              LOG_LEVEL         = "INFO",
              KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.this.id
            },
            {
              for key, value in var.model_configs["cloudwatch-search"] :
              upper(key) => tostring(value) if value != null
            },
          )
        }
        "mcp" = {
          cpu    = 512
          memory = 1024
          env_vars = {
            FASTMCP_LOG_LEVEL = "DEBUG"
          }
        }
      }
      tasks_role_statements = [
        {
          sid = "AllowCloudWatchRead"
          actions = [
            "cloudwatch:DescribeAlarms",
            "cloudwatch:DescribeAlarmHistory",
            "cloudwatch:GetMetricData",
            "cloudwatch:ListMetrics",
            "logs:DescribeLogGroups",
            "logs:DescribeQueryDefinitions",
            "logs:ListLogAnomalyDetectors",
            "logs:ListAnomalies",
            "logs:StartQuery",
            "logs:GetQueryResults",
            "logs:StopQuery",
          ]
          resources = ["*"]
        },
      ]
    }
    "mysql-search" = {
      containers = {
        "agent" = {
          cpu    = 512
          memory = 1024
          env_vars = merge(
            {
              AGENT_TYPE        = "mysql-search"
              AGENT_URL         = local.svc_discovery_urls["mysql-search"],
              LOG_LEVEL         = "INFO",
              KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.this.id
            },
            {
              for key, value in var.model_configs["mysql-search"] :
              upper(key) => tostring(value) if value != null
            },
          )
        }
        "mcp" = {
          cpu    = 512
          memory = 1024
          command = [
            "--hostname", var.mysql_connection.host,
            "--port", tostring(var.mysql_connection.port),
            "--secret_arn", var.mysql_connection.secret_arn,
            "--database", var.mysql_connection.db_name,
            "--region", data.aws_region.current.region,
            "--readonly", "True",
          ]
          env_vars = {
            FASTMCP_LOG_LEVEL = "DEBUG"
          }
        }
      }
      tasks_role_statements = [
        {
          sid = "AllowGetSecretValue"
          actions = [
            "secretsmanager:GetSecretValue",
          ]
          resources = [
            var.mysql_connection.secret_arn,
          ]
        },
      ]
    }
  }
}
