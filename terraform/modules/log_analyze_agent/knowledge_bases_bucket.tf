module "kb_source_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.12.0"

  bucket        = "${var.prefix}-log-analyze-kb-data-sources-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = module.encryption_keys["kb-data-sources"].key_id
      }
      bucket_key_enabled = true
    }
  }

  tags = {
    Name = "${var.prefix}-log-analyze-kb-data-sources-${data.aws_caller_identity.current.account_id}"
  }
}

# https://docs.aws.amazon.com/ja_jp/bedrock/latest/userguide/knowledge-base-setup.html
resource "aws_s3vectors_vector_bucket" "this" {
  vector_bucket_name = "${var.prefix}-log-analyze-kb-vectors-${data.aws_caller_identity.current.account_id}"
  force_destroy      = true

  encryption_configuration {
    sse_type    = "aws:kms"
    kms_key_arn = module.encryption_keys["kb-vectors"].key_arn
  }

  tags = {
    Name = "${var.prefix}-log-analyze-kb-vectors-${data.aws_caller_identity.current.account_id}"
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
