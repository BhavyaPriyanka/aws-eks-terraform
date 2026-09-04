resource "aws_acm_certificate" "localhelp" {
  domain_name       = "*.localhelp.store"
  validation_method = "DNS"

  tags = merge(
    var.common_tags,
    {
        Name = "${var.project_name}-${var.environment}"
    }
  )
}

resource "aws_route53_record" "localhelp" {
  for_each = {
    for dvo in aws_acm_certificate.localhelp.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 1
  type            = each.value.type
  zone_id         = data.aws_route53_zone.localhelp.zone_id
}

resource "aws_acm_certificate_validation" "localhelp" {
  certificate_arn         = aws_acm_certificate.localhelp.arn
  validation_record_fqdns = [for record in aws_route53_record.localhelp : record.fqdn]
}