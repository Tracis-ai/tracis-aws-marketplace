locals {
  required_pii_entity_types = toset([
    "AWS_ACCESS_KEY",
    "AWS_SECRET_KEY",
  ])
  pii_output_entity_types = setunion(
    local.required_pii_entity_types,
    var.pii_output_entity_types,
  )
  guardrail_profile_id = "apac.guardrail.v1:0"
}

moved {
  from = aws_bedrock_guardrail.this
  to   = aws_bedrock_guardrail.output
}

moved {
  from = aws_bedrock_guardrail_version.this
  to   = aws_bedrock_guardrail_version.output
}

resource "aws_bedrock_guardrail" "input" {
  name                      = "${var.prefix}-input-guardrail"
  blocked_input_messaging   = "入力制約に該当する内容がプロンプトに含まれるため回答できません。"
  blocked_outputs_messaging = "出力制約に該当する内容が生成結果に含まれるため回答できません。"
  description               = "${var.prefix}-input-guardrail"

  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "MEDIUM"
      output_strength = "NONE"
    }

    tier_config {
      tier_name = "STANDARD"
    }
  }

  cross_region_config {
    guardrail_profile_identifier = "arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:guardrail-profile/${local.guardrail_profile_id}"
  }

  sensitive_information_policy_config {
    dynamic "pii_entities_config" {
      for_each = local.required_pii_entity_types

      content {
        type           = pii_entities_config.value
        action         = "BLOCK"
        input_action   = "BLOCK"
        input_enabled  = true
        output_enabled = false
      }
    }
  }

  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }
}

resource "aws_bedrock_guardrail_version" "input" {
  guardrail_arn = aws_bedrock_guardrail.input.guardrail_arn
  description   = "${var.prefix}-input-guardrail"
  depends_on    = [aws_bedrock_guardrail.input]

  lifecycle {
    replace_triggered_by = [aws_bedrock_guardrail.input]
  }
}

resource "aws_bedrock_guardrail" "output" {
  name                      = "${var.prefix}-output-guardrail"
  blocked_input_messaging   = "入力制約に該当する内容がプロンプトに含まれるため回答できません。"
  blocked_outputs_messaging = "出力制約に該当する内容が生成結果に含まれるため回答できません。"
  description               = "${var.prefix}-output-guardrail"

  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "NONE"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "NONE"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "NONE"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "NONE"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "NONE"
      output_strength = "HIGH"
    }

    tier_config {
      tier_name = "STANDARD"
    }
  }

  cross_region_config {
    guardrail_profile_identifier = "arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:guardrail-profile/${local.guardrail_profile_id}"
  }

  dynamic "sensitive_information_policy_config" {
    for_each = length(local.pii_output_entity_types) > 0 ? [1] : []

    content {
      dynamic "pii_entities_config" {
        for_each = local.pii_output_entity_types

        content {
          type           = pii_entities_config.value
          action         = "ANONYMIZE"
          input_enabled  = false
          output_action  = "ANONYMIZE"
          output_enabled = true
        }
      }
    }
  }

  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }
}

resource "aws_bedrock_guardrail_version" "output" {
  guardrail_arn = aws_bedrock_guardrail.output.guardrail_arn
  description   = "${var.prefix}-output-guardrail"
  depends_on    = [aws_bedrock_guardrail.output]

  lifecycle {
    replace_triggered_by = [aws_bedrock_guardrail.output]
  }
}
