locals {
  # https://docs.aws.amazon.com/ja_jp/bedrock/latest/userguide/knowledge-base-supported.html
  embedding_model_id = "amazon.titan-embed-text-v2:0"
  vector_dimensions  = 1024
}

# https://docs.aws.amazon.com/ja_jp/bedrock/latest/userguide/knowledge-base-create.html
resource "aws_bedrockagent_knowledge_base" "this" {
  name     = "${var.prefix}-log-analyze-kb"
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

# https://docs.aws.amazon.com/ja_jp/bedrock/latest/userguide/data-source-connectors.html
resource "aws_bedrockagent_data_source" "this" {
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  name                 = "s3-data-source"
  data_deletion_policy = "RETAIN"

  data_source_configuration {
    type = "S3"

    s3_configuration {
      bucket_arn = module.kb_source_bucket.s3_bucket_arn
    }
  }

  # https://docs.aws.amazon.com/ja_jp/bedrock/latest/userguide/kb-data-source-customize-ingestion.html
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
