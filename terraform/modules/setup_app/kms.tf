data "aws_iam_policy_document" "kms_access_boundary" {
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
  statement {
    sid    = "DenyCryptographicOperationsOutsideSetupTables"
    effect = "Deny"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "kms:EncryptionContext:aws:dynamodb:tableName"
      values   = [for table in values(local.dynamodb_tables) : table.name]
    }
  }

  statement {
    sid    = "DenyCryptographicOperationsOutsideDynamoDb"
    effect = "Deny"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${data.aws_region.current.region}.amazonaws.com"]
    }

    condition {
      test     = "BoolIfExists"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }
  }
}

module "setup_data_encryption_key" {
  source  = "terraform-aws-modules/kms/aws"
  version = "4.2.0"

  description             = "CMK for encrypting data used by ${var.prefix}-tracis-ai-setup"
  aliases_use_name_prefix = true
  aliases = [
    "alias/${var.prefix}-tracis-ai-setup-data-encryption-key",
  ]

  enable_default_policy = true
  source_policy_documents = [
    data.aws_iam_policy_document.kms_access_boundary.json,
  ]

  deletion_window_in_days = 7
}
