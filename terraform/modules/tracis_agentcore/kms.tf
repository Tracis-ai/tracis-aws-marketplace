locals {
  kms_keys = {
    "kb-data-src" = {
      key_statements = []
    }
    "kb-vectors" = {
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

data "aws_iam_policy_document" "kms_account_boundary" {
  statement {
    sid    = "DenyExternalPrincipals"
    effect = "Deny"

    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalAccount"
      values = [
        data.aws_caller_identity.current.account_id,
      ]
    }

    condition {
      test     = "BoolIfExists"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyExternalServiceSources"
    effect = "Deny"

    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:PrincipalIsAWSService"
      values   = ["true"]
    }

    condition {
      test     = "Null"
      variable = "aws:SourceAccount"
      values   = ["false"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceAccount"
      values = [
        data.aws_caller_identity.current.account_id,
      ]
    }
  }
}

module "encryption_keys" {
  for_each = local.kms_keys

  source  = "terraform-aws-modules/kms/aws"
  version = "4.2.0"

  description             = "CMK for encrypting ${each.key} used by ${var.prefix}-tracis-ai-agent"
  aliases_use_name_prefix = true
  aliases = [
    "alias/${var.prefix}-tracis-ai-${each.key}-encryption-key"
  ]

  enable_default_policy = true
  key_statements        = each.value.key_statements
  source_policy_documents = [
    data.aws_iam_policy_document.kms_account_boundary.json,
  ]

  deletion_window_in_days = 7
}
