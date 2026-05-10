locals {
  kms_keys = {
    "kb-data-sources" = {
      key_statements = []
    }
    "kb-vectors" = {
      # https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/userguide/s3-vectors-data-encryption.html
      key_statements = [
        {
          sid    = "AllowS3VectorsServicePrincipal"
          effect = "Allow"
          actions = [
            "kms:Decrypt",
          ]
          resources = ["*"]
          principals = [
            {
              type = "Service"
              identifiers = [
                "indexing.s3vectors.amazonaws.com",
              ]
            },
          ]
          condition = [
            {
              test     = "ArnLike"
              variable = "aws:SourceArn"
              values = [
                "arn:aws:s3vectors:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:bucket/*",
              ]
            },
            {
              test     = "StringEquals"
              variable = "aws:SourceAccount"
              values = [
                data.aws_caller_identity.current.account_id,
              ]
            },
            {
              test     = "ForAnyValue:StringEquals"
              variable = "kms:EncryptionContextKeys"
              values = [
                "aws:s3vectors:arn",
                "aws:s3vectors:resource-id",
              ]
            },
          ]
        },
      ]
    }
  }
}

module "encryption_keys" {
  source  = "terraform-aws-modules/kms/aws"
  version = "4.2.0"

  for_each = local.kms_keys

  description             = "CMK for encrypting ${each.key} used by ${var.prefix}-log-analyze-agent"
  aliases_use_name_prefix = true
  aliases = [
    "alias/${var.prefix}-log-analyze-${each.key}-encryption-key"
  ]

  enable_default_policy = true
  key_statements        = each.value.key_statements

  deletion_window_in_days = 7
}
