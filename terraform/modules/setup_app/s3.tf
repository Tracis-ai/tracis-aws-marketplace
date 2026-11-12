data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "web_bucket" {
  statement {
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "${module.web_bucket.s3_bucket_arn}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values = [
        module.web_distribution.cloudfront_distribution_arn,
      ]
    }
  }
}

module "web_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.12.0"

  bucket        = "${var.prefix}-tracis-ai-setup-web-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  attach_policy = true
  policy        = data.aws_iam_policy_document.web_bucket.json
}

locals {
  web_directory = "${path.module}/web"
  web_files     = fileset(local.web_directory, "**")
  web_content_types = {
    avif  = "image/avif"
    css   = "text/css; charset=utf-8"
    gif   = "image/gif"
    html  = "text/html; charset=utf-8"
    ico   = "image/x-icon"
    jpeg  = "image/jpeg"
    jpg   = "image/jpeg"
    js    = "application/javascript; charset=utf-8"
    json  = "application/json"
    map   = "application/json"
    png   = "image/png"
    svg   = "image/svg+xml"
    ttf   = "font/ttf"
    txt   = "text/plain; charset=utf-8"
    webp  = "image/webp"
    woff  = "font/woff"
    woff2 = "font/woff2"
  }
}

resource "aws_s3_object" "web_asset" {
  for_each = setsubtract(local.web_files, ["index.html"])

  bucket       = module.web_bucket.s3_bucket_id
  key          = each.value
  source       = "${local.web_directory}/${each.value}"
  source_hash  = filemd5("${local.web_directory}/${each.value}")
  content_type = lookup(local.web_content_types, reverse(split(".", each.value))[0], "application/octet-stream")
  cache_control = (
    startswith(each.value, "assets/")
    ? join(",", [
      "public",
      "max-age=31536000",
      "immutable",
    ])
    : join(",", [
      "no-cache",
      "no-store",
      "must-revalidate",
    ])
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_s3_object" "web_index" {
  bucket       = module.web_bucket.s3_bucket_id
  key          = "index.html"
  source       = "${local.web_directory}/index.html"
  source_hash  = filemd5("${local.web_directory}/index.html")
  content_type = "text/html; charset=utf-8"
  cache_control = join(",", [
    "no-cache",
    "no-store",
    "must-revalidate",
  ])

  depends_on = [
    aws_s3_object.web_asset,
  ]
}
