locals {
  dynamodb_tables = {
    session = {
      name               = "${var.prefix}-tracis-ai-setup-sessions"
      hash_key           = "id"
      range_key          = null
      ttl_attribute_name = "expires_at"
    }
    context = {
      name               = "${var.prefix}-tracis-ai-contexts"
      hash_key           = "pk"
      range_key          = "sk"
      ttl_attribute_name = "expires_at"
    }
  }
}

resource "aws_dynamodb_table" "this" {
  for_each = local.dynamodb_tables

  name         = each.value.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = each.value.hash_key
  range_key    = each.value.range_key

  dynamic "attribute" {
    for_each = toset(compact([each.value.hash_key, each.value.range_key]))

    content {
      name = attribute.value
      type = "S"
    }
  }

  ttl {
    attribute_name = each.value.ttl_attribute_name
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = module.setup_data_encryption_key.key_arn
  }
}

data "aws_iam_policy_document" "table_access_boundary" {
  for_each = aws_dynamodb_table.this

  statement {
    sid    = "AllowSetupApiDataAccess"
    effect = "Allow"
    actions = concat(
      [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
      ],
      each.key == "session" ? ["dynamodb:UpdateItem"] : [],
    )
    resources = [each.value.arn]

    principals {
      type = "AWS"
      identifiers = [
        module.setup_api_function.lambda_role_arn,
      ]
    }
  }

  statement {
    sid    = "DenyUnexpectedWritePrincipal"
    effect = "Deny"
    actions = concat(
      [
        "dynamodb:PutItem",
      ],
      each.key == "session" ? ["dynamodb:UpdateItem"] : [],
    )
    resources = [each.value.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values = [
        module.setup_api_function.lambda_role_arn,
      ]
    }
  }

  statement {
    sid    = "DenyUnsupportedWriteOperations"
    effect = "Deny"
    actions = concat(
      [
        "dynamodb:DeleteItem",
        "dynamodb:ConditionCheckItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:PartiQLInsert",
        "dynamodb:PartiQLUpdate",
        "dynamodb:PartiQLDelete",
      ],
      each.key == "context" ? ["dynamodb:UpdateItem"] : [],
    )
    resources = [
      each.value.arn,
      "${each.value.arn}/index/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    sid    = "DenyTransactionalWriteOperations"
    effect = "Deny"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [each.value.arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "dynamodb:EnclosingOperation"
      values = [
        "TransactWriteItems",
      ]
    }
  }

  statement {
    sid     = "DenyAccessOutsideAccount"
    effect  = "Deny"
    actions = ["dynamodb:*"]
    resources = [
      each.value.arn,
      "${each.value.arn}/*",
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
  }
}

resource "aws_dynamodb_resource_policy" "table_access_boundary" {
  for_each = aws_dynamodb_table.this

  resource_arn = each.value.arn
  policy       = data.aws_iam_policy_document.table_access_boundary[each.key].json
}
