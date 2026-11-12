locals {
  is_inference_profile_for_context_generation = (
    can(regex(":(application-)?inference-profile/", var.context_generation_config.model_id)) ||
    (!startswith(var.context_generation_config.model_id, "arn:") && (
      length(split(".", var.context_generation_config.model_id)) == 1 ||
      can(regex("^(global|apac|[a-z]{2}(-gov)?)\\.", var.context_generation_config.model_id))
    ))
  )
  source_inference_profile_arns_for_context_generation = flatten([
    for result in data.aws_bedrock_inference_profiles.context_generation : [
      for profile in result.inference_profile_summaries : profile.inference_profile_arn
      if toset([for model in profile.models : model.model_arn]) == toset([
        for model in data.aws_bedrock_inference_profile.context_generation[0].models : model.model_arn
      ])
    ]
  ])
  invocation_resource_arns_for_context_generation = (
    local.is_inference_profile_for_context_generation
    ? distinct(concat(
      local.source_inference_profile_arns_for_context_generation,
      [
        data.aws_bedrock_inference_profile.context_generation[0].inference_profile_arn,
      ],
      [
        for model in data.aws_bedrock_inference_profile.context_generation[0].models :
        model.model_arn
      ],
      [
        for model in data.aws_bedrock_inference_profile.context_generation[0].models :
        "arn:aws:bedrock:${data.aws_region.current.region}::foundation-model/${split("/", model.model_arn)[1]}"
      ],
      [
        for model in data.aws_bedrock_inference_profile.context_generation[0].models :
        "arn:aws:bedrock:::foundation-model/${split("/", model.model_arn)[1]}"
      ],
    ))
    : [(
      startswith(var.context_generation_config.model_id, "arn:")
      ? var.context_generation_config.model_id
      : "arn:aws:bedrock:${data.aws_region.current.region}::foundation-model/${var.context_generation_config.model_id}"
    )]
  )
}

data "aws_bedrock_inference_profile" "context_generation" {
  count = local.is_inference_profile_for_context_generation ? 1 : 0

  inference_profile_id = var.context_generation_config.model_id
}

data "aws_bedrock_inference_profiles" "context_generation" {
  count = try(data.aws_bedrock_inference_profile.context_generation[0].type == "APPLICATION", false) ? 1 : 0

  type = "SYSTEM_DEFINED"
}
