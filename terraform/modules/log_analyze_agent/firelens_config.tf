module "firelens_config_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.12.0"

  bucket        = "${var.prefix}-firelens-config-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name = "${var.prefix}-firelens-config-${data.aws_caller_identity.current.account_id}"
  }
}

resource "aws_s3_object" "firelens_config" {
  bucket  = module.firelens_config_bucket.s3_bucket_id
  key     = "fluent-bit.conf"
  content = file("${path.module}/firelens/fluent-bit.conf")
  etag    = filemd5("${path.module}/firelens/fluent-bit.conf")
}

