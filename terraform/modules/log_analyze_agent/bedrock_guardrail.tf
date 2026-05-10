# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrock_guardrail#content-policy-config
resource "aws_bedrock_guardrail" "this" {
  name                      = "${var.prefix}-log-analyze-guardrail"
  blocked_input_messaging   = "入力制約に該当する内容がプロンプトに含まれるため回答できません。"
  blocked_outputs_messaging = "出力制約に該当する内容が生成結果に含まれるため回答できません。"
  description               = "${var.prefix}-log-analyze-guardrail"

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
      input_strength  = "HIGH"
      output_strength = "NONE"
    }

    tier_config {
      tier_name = "STANDARD"
    }
  }

  # tier_nameでSTANDARDを設定するためにクロスリージョン推論が必要
  # https://docs.aws.amazon.com/ja_jp/bedrock/latest/userguide/guardrails-tiers.html#guardrails-tiers-migration
  cross_region_config {
    guardrail_profile_identifier = "arn:aws:bedrock:ap-northeast-1:${data.aws_caller_identity.current.account_id}:guardrail-profile/apac.guardrail.v1:0"
  }

  word_policy_config {
    managed_word_lists_config {
      type = "PROFANITY"
    }
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrock_guardrail_version
resource "aws_bedrock_guardrail_version" "this" {
  guardrail_arn = aws_bedrock_guardrail.this.guardrail_arn
  description   = "${var.prefix}-log-analyze-guardrail"
  depends_on    = [aws_bedrock_guardrail.this]

  lifecycle {
    replace_triggered_by = [
      aws_bedrock_guardrail.this
    ]
  }
}
