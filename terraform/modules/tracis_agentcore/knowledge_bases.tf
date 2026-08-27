locals {
  embedding_model_id = "amazon.titan-embed-text-v2:0"
  vector_dimensions  = 1024
}

module "kb_source_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.12.0"

  bucket        = "${var.prefix}-tracis-ai-kb-data-src-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = module.encryption_keys["kb-data-src"].key_id
      }
      bucket_key_enabled = true
    }
  }
}

resource "aws_s3vectors_vector_bucket" "this" {
  vector_bucket_name = "${var.prefix}-tracis-ai-kb-vectors-${data.aws_caller_identity.current.account_id}"
  force_destroy      = true

  encryption_configuration {
    sse_type    = "aws:kms"
    kms_key_arn = module.encryption_keys["kb-vectors"].key_arn
  }
}

resource "aws_s3vectors_index" "this" {
  vector_bucket_name = aws_s3vectors_vector_bucket.this.vector_bucket_name
  index_name         = "embeddings"

  data_type       = "float32"
  dimension       = local.vector_dimensions
  distance_metric = "cosine"

  metadata_configuration {
    non_filterable_metadata_keys = [
      "AMAZON_BEDROCK_TEXT",
      "AMAZON_BEDROCK_METADATA",
    ]
  }
}

resource "aws_bedrockagent_knowledge_base" "this" {
  name     = "${var.prefix}-tracis-ai-kb"
  role_arn = module.kb_role.arn

  knowledge_base_configuration {
    type = "VECTOR"

    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.region}::foundation-model/${local.embedding_model_id}"

      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = local.vector_dimensions
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "S3_VECTORS"

    s3_vectors_configuration {
      index_arn = aws_s3vectors_index.this.index_arn
    }
  }
}

resource "aws_bedrockagent_data_source" "this" {
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  name                 = "s3-data-src"
  data_deletion_policy = "RETAIN"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn = module.kb_source_bucket.s3_bucket_arn
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "SEMANTIC"

      semantic_chunking_configuration {
        breakpoint_percentile_threshold = 90
        buffer_size                     = 1
        max_token                       = 300
      }
    }
  }
}

resource "aws_cloudwatch_log_group" "kb" {
  name              = "/aws/vendedlogs/bedrock/knowledge-base/APPLICATION_LOGS/${aws_bedrockagent_knowledge_base.this.id}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_delivery_source" "kb" {
  name         = "${aws_bedrockagent_knowledge_base.this.name}-log-delivery-src"
  log_type     = "APPLICATION_LOGS"
  resource_arn = aws_bedrockagent_knowledge_base.this.arn
}

resource "aws_cloudwatch_log_delivery_destination" "kb" {
  name = "${aws_bedrockagent_knowledge_base.this.name}-log-delivery-dest"

  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.kb.arn
  }
}

resource "aws_cloudwatch_log_delivery" "kb" {
  delivery_source_name     = aws_cloudwatch_log_delivery_source.kb.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.kb.arn
}

data "aws_iam_policy_document" "kb_logging" {
  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.kb.arn}:log-stream:*"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*",
      ]
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "kb_logging" {
  policy_name     = "${aws_bedrockagent_knowledge_base.this.name}-logging-policy"
  policy_document = data.aws_iam_policy_document.kb_logging.json
}
