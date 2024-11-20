locals {
  console_domain = "${var.console_subdomain}.${var.zone}"
}

data "cloudflare_zone" "zachtech" {
  name = var.zone
}

resource "cloudflare_record" "console_a_record" {
  zone_id = data.cloudflare_zone.zachtech.id
  name    = local.console_domain
  content = aws_cloudfront_distribution.s3_distribution.domain_name
  type    = "CNAME"
  ttl     = 60
  proxied = false

  comment = join(",", [for key, value in merge(var.default_tags, { Domain = var.console_subdomain }) : "${key}=${value}"])
}

resource "aws_acm_certificate" "console_cert" {
  provider = aws.us-east-1

  domain_name       = local.console_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.default_tags, { Domain = var.console_subdomain })
}

resource "cloudflare_record" "console_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.console_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      value = dvo.resource_record_value
    }
  }

  zone_id = data.cloudflare_zone.zachtech.id
  name    = each.value.name
  content = each.value.value
  type    = "CNAME"
  ttl     = 60
  proxied = false

  comment = join(",", [for key, value in merge(var.default_tags, { Domain = var.console_subdomain }) : "${key}=${value}"])
}

resource "aws_acm_certificate_validation" "console_cert_validation_wait" {
  provider = aws.us-east-1

  certificate_arn         = aws_acm_certificate.console_cert.arn
  validation_record_fqdns = [for record in cloudflare_record.console_cert_validation : record.hostname]
}
