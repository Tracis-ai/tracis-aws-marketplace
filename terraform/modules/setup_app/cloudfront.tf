data "aws_region" "current" {}

module "web_distribution" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.7.1"

  comment             = "TracisAI Setup application"
  default_root_object = "index.html"
  is_ipv6_enabled     = true
  price_class         = "PriceClass_200"

  origin_access_control = {
    "web-s3" = {
      name             = "${var.prefix}-tracis-ai-setup-web-oac"
      description      = "OAC for the TracisAI setup SPA"
      origin_type      = "s3"
      signing_behavior = "always"
      signing_protocol = "sigv4"
    }
  }

  origin = {
    "web-s3" = {
      domain_name               = module.web_bucket.s3_bucket_bucket_regional_domain_name
      origin_access_control_key = "web-s3"
    }
    "api-gateway" = {
      domain_name = "${aws_api_gateway_rest_api.this.id}.execute-api.${data.aws_region.current.region}.amazonaws.com"
      origin_path = "/setup"
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "https-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  response_headers_policies = {
    "security" = {
      name = "${var.prefix}-tracis-ai-setup-web-security"
      security_headers_config = {
        content_security_policy = {
          content_security_policy = join(" ", [
            "default-src 'none';",
            "script-src 'self' 'unsafe-inline';",
            "style-src 'self' 'unsafe-inline';",
            "connect-src 'self';",
            "img-src 'self' data:;",
            "base-uri 'none';",
            "frame-ancestors 'none'",
          ])
          override = true
        }
        content_type_options = {
          override = true
        }
        frame_options = {
          frame_option = "DENY"
          override     = true
        }
        referrer_policy = {
          referrer_policy = "no-referrer"
          override        = true
        }
        strict_transport_security = {
          access_control_max_age_sec = 31536000
          include_subdomains         = true
          override                   = true
          preload                    = true
        }
      }
    }
  }

  cloudfront_functions = {
    "spa" = {
      name    = "${var.prefix}-tracis-ai-setup-spa"
      runtime = "cloudfront-js-2.0"
      comment = "Route SPA navigation to index.html on the web origin"
      publish = true
      code    = file("${path.module}/src/cff_spa_fallback.js")
    }
  }

  default_cache_behavior = {
    target_origin_id       = "web-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods = [
      "GET",
      "HEAD",
      "OPTIONS"
    ]
    cached_methods = [
      "GET",
      "HEAD",
      "OPTIONS",
    ]
    cache_policy_name           = "Managed-CachingDisabled"
    response_headers_policy_key = "security"
    compress                    = true
    function_association = {
      viewer-request = {
        function_key = "spa"
      }
    }
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/assets/*"
      target_origin_id       = "web-s3"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods = [
        "GET",
        "HEAD",
        "OPTIONS",
      ]
      cached_methods = [
        "GET",
        "HEAD",
        "OPTIONS",
      ]
      cache_policy_name           = "Managed-CachingOptimized"
      response_headers_policy_key = "security"
      compress                    = true
    },
    {
      path_pattern           = "/api/*"
      target_origin_id       = "api-gateway"
      viewer_protocol_policy = "https-only"
      allowed_methods = [
        "GET",
        "HEAD",
        "OPTIONS",
        "PUT",
        "POST",
        "PATCH",
        "DELETE",
      ]
      cached_methods = [
        "GET",
        "HEAD",
      ]
      cache_policy_name           = "Managed-CachingDisabled"
      origin_request_policy_name  = "Managed-AllViewerExceptHostHeader"
      response_headers_policy_key = "security"
      compress                    = true
    },
  ]

  restrictions = {
    geo_restriction = {
      restriction_type = "none"
    }
  }

  viewer_certificate = {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1"
  }
}
