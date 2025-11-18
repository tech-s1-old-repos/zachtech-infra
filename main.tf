locals {
  s3_origin_id = "zone-s3-origin"
  zone_bucket_name = "${var.zone}-${random_uuid.bucket_suffix.result}"
}

data "aws_caller_identity" "current" {}

resource "random_uuid" "bucket_suffix" {}

resource "aws_s3_bucket" "zone_bucket" {
  bucket        = local.zone_bucket_name
  force_destroy = true

  tags = merge(var.default_tags, { Domain = var.zone })
}

resource "aws_s3_bucket" "logs_bucket" {
  bucket        = "${local.zone_bucket_name}-logs"
  force_destroy = true

  tags = merge(var.default_tags, { Domain = "logs" })
}

resource "aws_s3_bucket_lifecycle_configuration" "logs_bucket_7_days" {
  bucket = aws_s3_bucket.logs_bucket.id

  rule {
    id     = "7-day"
    status = "Enabled"

    filter {
    }

    expiration {
      days = 7
    }
  }
}


resource "aws_s3_bucket_ownership_controls" "logs_bucket_ownership" {
  bucket = aws_s3_bucket.logs_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.logs_bucket_ownership]

  bucket = aws_s3_bucket.logs_bucket.id
  acl    = "log-delivery-write"
}


resource "aws_s3_bucket_public_access_block" "logs_bucket" {
  bucket = aws_s3_bucket.logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_bucket_policy" "zone_bucket" {
  bucket = aws_s3_bucket.zone_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.zone_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "zone_bucket" {
  bucket = aws_s3_bucket.zone_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "${local.zone_bucket_name}-oac"
  description                       = "OAC for ${local.zone_bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.zone_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "Dist for ${local.zone_bucket_name}"

  aliases = [var.zone]

  # TODO: Disabled currently
  #   logging_config {
  #     include_cookies = true
  #     bucket          = "${var.logs_bucket}.s3.amazonaws.com"
  #     prefix          = "${local.zone_bucket_name}/"
  #   }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

  }

  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.zone_cert_validation_wait.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.default_tags, {
    Domain = var.zone
  })
}

