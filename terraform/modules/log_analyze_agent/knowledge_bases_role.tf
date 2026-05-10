# https://docs.aws.amazon.com/ja_jp/bedrock/latest/userguide/kb-permissions.html
module "kb_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "6.4.0"

  name            = "${var.prefix}-log-analyze-kb-role"
  use_name_prefix = false

  trust_policy_permissions = {
    "TrustBedrockService" = {
      effect = "Allow"
      actions = [
        "sts:AssumeRole",
      ]
      principals = [
        {
          type = "Service"
          identifiers = [
            "bedrock.amazonaws.com",
          ]
        },
      ]
      condition = [
        {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values = [
            data.aws_caller_identity.current.account_id,
          ]
        },
      ]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    "ListBedrockModels" = {
      effect = "Allow"
      actions = [
        "bedrock:ListFoundationModels",
        "bedrock:ListCustomModels",
      ]
      resources = ["*"]
    }
    "InvokeBedrockModel" = {
      effect = "Allow"
      actions = [
        "bedrock:InvokeModel",
      ]
      resources = [
        "arn:aws:bedrock:${data.aws_region.current.region}::foundation-model/*",
      ]
    }
    "ReadDataSources" = {
      effect = "Allow"
      actions = [
        "s3:ListBucket",
        "s3:GetObject",
      ]
      resources = [
        module.kb_source_bucket.s3_bucket_arn,
        "${module.kb_source_bucket.s3_bucket_arn}/*",
      ]
    }
    "S3VectorsAccess" = {
      effect = "Allow"
      actions = [
        "s3vectors:PutVectors",
        "s3vectors:GetVectors",
        "s3vectors:DeleteVectors",
        "s3vectors:QueryVectors",
        "s3vectors:GetIndex",
      ]
      resources = [
        aws_s3vectors_index.this.index_arn,
      ]
    }
    "KmsKeyAccess" = {
      effect = "Allow"
      actions = [
        "kms:GenerateDataKey",
        "kms:Decrypt",
      ]
      resources = [
        module.encryption_keys["kb-data-sources"].key_arn,
        module.encryption_keys["kb-vectors"].key_arn,
      ]
    }
  }
}
