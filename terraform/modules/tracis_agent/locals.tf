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

  service_name                  = "${var.prefix}-tracis-agent-service"
  agent_process_timeout_seconds = 300

  containers = {
    "agent" = {
      image  = var.container_image_url
      cpu    = 512
      memory = 1024
      env_vars = merge(
        {
          LOG_LEVEL                     = "INFO",
          FASTMCP_LOG_LEVEL             = "INFO",
          AGENT_PROCESS_TIMEOUT_SECONDS = tostring(local.agent_process_timeout_seconds),
          SQS_QUEUE_URL                 = module.sqs.queue_url,
          SQS_MAX_RETRY_COUNT           = "5",
          MCP_MYSQL_HOSTNAME            = var.mysql_connection.host,
          MCP_MYSQL_PORT                = tostring(var.mysql_connection.port),
          MCP_MYSQL_DATABASE            = var.mysql_connection.db_name,
          MCP_MYSQL_SECRET_ARN          = var.mysql_connection.secret_arn,
          GUARDRAIL_ID                  = aws_bedrock_guardrail.this.guardrail_id
          GUARDRAIL_VERSION             = aws_bedrock_guardrail_version.this.version
          ENABLE_GUARDRAIL_TRACE        = try(tostring(var.model_config.enable_guardrail_trace), "disabled")
          KNOWLEDGE_BASE_ID             = aws_bedrockagent_knowledge_base.this.id
        },
        {
          for key, value in {
            BEDROCK_MODEL_ID = try(tostring(var.model_config.bedrock_model_id), null)
            MAX_TOKENS       = try(tostring(var.model_config.max_tokens), null)
            TEMPERATURE      = try(tostring(var.model_config.temperature), null)
            TOP_P            = try(tostring(var.model_config.top_p), null)
          } : key => value if value != null
        },
      )
      secrets = [
        {
          name      = "SLACK_BOT_TOKEN"
          valueFrom = "${var.slack_secret_arn}:SLACK_BOT_TOKEN::"
        }
      ]
      log_configuration = {
        logDriver = "awsfirelens"
        options = {
          log-driver-buffer-limit = "10485760"
        }
      }
      firelens_configuration = null
      mount_points           = null
      user                   = null
      health_check           = null
    }
    "log-router" = {
      image  = "public.ecr.aws/aws-observability/aws-for-fluent-bit:init-latest"
      cpu    = 256
      memory = 512
      env_vars = {
        ACCOUNT_ID               = data.aws_caller_identity.current.account_id
        aws_fluent_bit_init_s3_1 = aws_s3_object.firelens_config.arn
        CW_LOG_GROUP_NAME        = "/aws/ecs/${local.service_name}/agent"
      }
      secrets = null
      log_configuration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/aws/ecs/${local.service_name}/log-router"
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "/ecs"
        }
      }
      firelens_configuration = {
        type = "fluentbit"
        options = {
          enable-ecs-log-metadata = "true"
        }
      }
      mount_points = [
        {
          sourceVolume  = "tmp"
          containerPath = "/tmp"
          readOnly      = false
        }
      ]
      user = "0"
      health_check = {
        command = [
          "CMD-SHELL",
          "curl -f http://127.0.0.1:2020/api/v1/health || exit 1",
        ]
        interval = 30
        timeout  = 5
        retries  = 3
      }
    }
  }

  tasks_role_statements = [
    {
      sid = "AllowECSTasksDescribe"
      actions = [
        "ecs:DescribeTasks",
      ]
      resources = [
        "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:task/${var.prefix}-tracis-agent-cluster/*",
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
