module "kb_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.4.0"

  name            = "${var.prefix}-tracis-ai-kb-role"
  use_name_prefix = false

  trust_policy_permissions = {
    TrustBedrockService = {
      effect  = "Allow"
      actions = ["sts:AssumeRole"]
      principals = [
        {
          type        = "Service"
          identifiers = ["bedrock.amazonaws.com"]
        },
      ]
      condition = [
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = [data.aws_caller_identity.current.account_id]
        },
      ]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    ListBedrockModels = {
      effect = "Allow"
      actions = [
        "bedrock:ListCustomModels",
        "bedrock:ListFoundationModels",
      ]
      resources = ["*"]
    }
    InvokeBedrockModel = {
      effect    = "Allow"
      actions   = ["bedrock:InvokeModel"]
      resources = ["arn:aws:bedrock:${data.aws_region.current.region}::foundation-model/*"]
    }
    ReadDataSources = {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:ListBucket",
      ]
      resources = [
        module.kb_source_bucket.s3_bucket_arn,
        "${module.kb_source_bucket.s3_bucket_arn}/*",
      ]
    }
    S3VectorsAccess = {
      effect = "Allow"
      actions = [
        "s3vectors:DeleteVectors",
        "s3vectors:GetIndex",
        "s3vectors:GetVectors",
        "s3vectors:PutVectors",
        "s3vectors:QueryVectors",
      ]
      resources = [aws_s3vectors_index.this.index_arn]
    }
    KmsKeyAccess = {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
      ]
      resources = [
        module.encryption_keys["kb-data-src"].key_arn,
        module.encryption_keys["kb-vectors"].key_arn,
      ]
    }
  }
}
