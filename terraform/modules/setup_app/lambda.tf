module "schema_reader" {
  source = "../tools/lambda"

  prefix               = "${var.prefix}-tracisai"
  function_name_suffix = "schema-reader"
  enabled_tools        = tolist(var.enabled_tools)
  container_image_urls = var.schema_reader_image_urls
  subnet_ids           = var.lambda_subnet_ids
  tool_sg_ids          = var.tool_sg_ids
  mysql_connection     = var.mysql_connection
  handler              = "dist/src/index.schemaReaderHandler"
}

module "setup_api_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "8.8.0"

  function_name           = "${var.prefix}-tracis-ai-setup-api-function"
  architectures           = ["arm64"]
  create_package          = false
  ignore_source_code_hash = true
  package_type            = "Image"
  image_uri               = var.setup_api_image_url
  memory_size             = 256
  timeout                 = 60

  environment_variables = merge(
    {
      BEDROCK_MODEL_ID             = var.context_generation_config.model_id
      MAX_TOKENS                   = tostring(var.context_generation_config.max_tokens)
      TRACIS_RUNTIME_MODE          = "setup"
      AWS_LWA_READINESS_CHECK_PATH = "/healthz"
      CHAT_TOOLS_SECRET_ARN        = var.chat_tools_secret_arn
      CONTEXT_TABLE_NAME           = aws_dynamodb_table.this["context"].name
      SESSION_TABLE_NAME           = aws_dynamodb_table.this["session"].name
      WEB_APP_BASE_URL             = "https://${module.web_distribution.cloudfront_distribution_domain_name}"
    },
    {
      for key, function in module.schema_reader.functions :
      "${upper(key)}_SCHEMA_READER_FUNCTION_ARN" => function.arn
    },
    var.knowledge_bases != null ? {
      KNOWLEDGE_BASE_ID     = var.knowledge_bases.id
      KB_DATA_SOURCE_ID     = var.knowledge_bases.data_source_id
      KB_SOURCE_BUCKET_NAME = var.knowledge_bases.data_source_bucket.name
      KB_SOURCE_KMS_KEY_ARN = var.knowledge_bases.data_source_bucket.encryption_key_arn
    } : {},
  )

  role_name                = "${var.prefix}-tracis-ai-setup-api-function-role"
  attach_policy_statements = true
  policy_name              = "setup-function"
  policy_statements = merge(
    {
      "invoke-context-generation-model" = {
        actions   = ["bedrock:InvokeModel"]
        resources = local.invocation_resource_arns_for_context_generation
      },
      "describe-log-groups" = {
        actions   = ["logs:DescribeLogGroups"]
        resources = ["*"]
      },
      "context-item-access" = {
        actions = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
        ]
        resources = [
          aws_dynamodb_table.this["context"].arn,
        ]
      },
      "get-secret" = {
        actions = [
          "secretsmanager:GetSecretValue",
        ]
        resources = [var.chat_tools_secret_arn]
      },
      "decrypt-setup-data" = {
        actions   = ["kms:Decrypt"]
        resources = [module.setup_data_encryption_key.key_arn]
        condition = [
          {
            test     = "StringEquals"
            variable = "kms:ViaService"
            values   = ["dynamodb.${data.aws_region.current.region}.amazonaws.com"]
          },
          {
            test     = "StringEquals"
            variable = "kms:CallerAccount"
            values   = [data.aws_caller_identity.current.account_id]
          },
        ]
      },
      "session-item-access" = {
        actions = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
        ]
        resources = [
          aws_dynamodb_table.this["session"].arn,
        ]
      },
    },
    var.knowledge_bases != null ? {
      "publish-kb-context" = {
        actions = ["s3:PutObject"]
        resources = [
          "${var.knowledge_bases.data_source_bucket.arn}/contexts/*",
        ]
      },
      "sync-knowledge-base" = {
        actions = [
          "bedrock:StartIngestionJob",
          "bedrock:GetIngestionJob",
        ]
        resources = [
          var.knowledge_bases.arn,
        ]
      },
    } : {},
    var.knowledge_bases != null ? {
      "encrypt-kb-context" = {
        actions = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
        ]
        resources = [
          var.knowledge_bases.data_source_bucket.encryption_key_arn,
        ]
        condition = [
          {
            test     = "StringEquals"
            variable = "kms:ViaService"
            values = [
              "s3.${data.aws_region.current.region}.amazonaws.com",
            ]
          },
          {
            test     = "StringEquals"
            variable = "kms:EncryptionContext:aws:s3:arn"
            values = [
              var.knowledge_bases.data_source_bucket.arn,
            ]
          },
        ]
      },
    } : {},
  )

  cloudwatch_logs_retention_in_days = 14
}

locals {
  setup_api_invocation_source_arns = distinct([
    for method in values(local.method_definitions) :
    "${aws_api_gateway_rest_api.this.execution_arn}/${aws_api_gateway_stage.this.stage_name}/${method.http_method}${replace(aws_api_gateway_resource.child[method.resource_key].path, "{proxy+}", "*")}"
  ])
}

data "aws_iam_policy_document" "setup_api_function_access_boundary" {
  statement {
    sid     = "AllowInvocationFromApiGateway"
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.setup_api_function.lambda_function_arn,
      "${module.setup_api_function.lambda_function_arn}:*",
    ]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = local.setup_api_invocation_source_arns
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "DenyUnexpectedServicePrincipal"
    effect  = "Deny"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.setup_api_function.lambda_function_arn,
      "${module.setup_api_function.lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalServiceName"
      values   = ["apigateway.amazonaws.com"]
    }
  }

  statement {
    sid     = "DenyUnexpectedSourceArn"
    effect  = "Deny"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.setup_api_function.lambda_function_arn,
      "${module.setup_api_function.lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotLike"
      variable = "aws:SourceArn"
      values   = local.setup_api_invocation_source_arns
    }
  }

  statement {
    sid     = "DenyUnexpectedSourceAccount"
    effect  = "Deny"
    actions = ["lambda:InvokeFunction"]
    resources = [
      module.setup_api_function.lambda_function_arn,
      "${module.setup_api_function.lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "DenyFunctionUrl"
    effect  = "Deny"
    actions = ["lambda:InvokeFunctionUrl"]
    resources = [
      module.setup_api_function.lambda_function_arn,
      "${module.setup_api_function.lambda_function_arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_lambda_resource_policy" "setup_api_function_access_boundary" {
  resource_arn = module.setup_api_function.lambda_function_arn
  policy       = data.aws_iam_policy_document.setup_api_function_access_boundary.json
}

data "aws_iam_policy_document" "schema_reader_function_access_boundary" {
  for_each = module.schema_reader.functions

  statement {
    sid     = "AllowInvocationFromSetupApiRole"
    effect  = "Allow"
    actions = ["lambda:InvokeFunction"]
    resources = [
      each.value.arn,
      "${each.value.arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:PrincipalArn"
      values   = [module.setup_api_function.lambda_role_arn]
    }
  }

  statement {
    sid     = "DenyUnexpectedPrincipal"
    effect  = "Deny"
    actions = ["lambda:InvokeFunction"]
    resources = [
      each.value.arn,
      "${each.value.arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = [module.setup_api_function.lambda_role_arn]
    }
  }

  statement {
    sid     = "DenyFunctionUrl"
    effect  = "Deny"
    actions = ["lambda:InvokeFunctionUrl"]
    resources = [
      each.value.arn,
      "${each.value.arn}:*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_lambda_resource_policy" "schema_reader_function_access_boundary" {
  for_each = module.schema_reader.functions

  resource_arn = each.value.arn
  policy       = data.aws_iam_policy_document.schema_reader_function_access_boundary[each.key].json
}
