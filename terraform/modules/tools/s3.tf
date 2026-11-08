data "aws_iam_policy_document" "s3_account_boundary" {
  statement {
    sid    = "DenyExternalPrincipals"
    effect = "Deny"

    actions = ["s3:*"]
    resources = [
      "_S3_BUCKET_ARN_",
      "_S3_BUCKET_ARN_/*",
    ]

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

    actions = ["s3:*"]
    resources = [
      "_S3_BUCKET_ARN_",
      "_S3_BUCKET_ARN_/*",
    ]

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

module "tool_schema_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.12.0"

  bucket = "${var.prefix}-tracis-ai-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"

  attach_policy = true
  policy        = data.aws_iam_policy_document.s3_account_boundary.json
}

module "tool_schema_objects" {
  for_each = local.enabled_tool_configs

  source       = "terraform-aws-modules/s3-bucket/aws//modules/object"
  version      = "5.12.0"
  bucket       = module.tool_schema_bucket.s3_bucket_id
  key          = local.tool_schema_object_keys[each.key]
  file_source  = each.value.tool_schema_source_path
  source_hash  = filemd5(each.value.tool_schema_source_path)
  content_type = "application/json"
}
