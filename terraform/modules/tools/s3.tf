module "tool_schema_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "5.12.0"

  bucket = "${var.prefix}-tracis-ai-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
}

module "tool_schema_objects" {
  source   = "terraform-aws-modules/s3-bucket/aws//modules/object"
  version  = "5.12.0"
  for_each = local.enabled_tool_configs

  bucket       = module.tool_schema_bucket.s3_bucket_id
  key          = local.tool_schema_object_keys[each.key]
  file_source  = each.value.tool_schema_source_path
  source_hash  = filemd5(each.value.tool_schema_source_path)
  content_type = "application/json"
}
