resource "aws_bedrock_guardrail" "this" {
  name                      = "${var.prefix}-tracis-guardrail"
  blocked_input_messaging   = "入力制約に該当する内容がプロンプトに含まれるため回答できません。"
  blocked_outputs_messaging = "出力制約に該当する内容が生成結果に含まれるため回答できません。"
  description               = "${var.prefix}-tracis-guardrail"

  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "INSULTS"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "SEXUAL"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "MISCONDUCT"
      input_strength  = "HIGH"
      output_strength = "HIGH"
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
    guardrail_profile_identifier = "arn:aws:bedrock:ap-northeast-1:${data.aws_caller_identity.current.account_id}:guardrail-profile/apac.guardrail.v1:0"
  }

  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }
}

resource "aws_bedrock_guardrail_version" "this" {
  guardrail_arn = aws_bedrock_guardrail.this.guardrail_arn
  description   = "${var.prefix}-tracis-guardrail"
  depends_on    = [aws_bedrock_guardrail.this]

  lifecycle {
    replace_triggered_by = [
      aws_bedrock_guardrail.this
    ]
  }
}
