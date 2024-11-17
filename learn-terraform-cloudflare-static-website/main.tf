
# The aws provider block authenticates to aws, scoped to the region specified by the aws_region input variable. 
provider "aws" {
  region = var.aws_region
}

# The cloudflare provider authenticates using the scoped api token, accessed by an environment variable.
provider "cloudflare" {}

#the aws_s3_bucket resource creates an S3 bucket with the name specified by the site_domain input variable.
resource "aws_s3_bucket" "site" {
  bucket = var.site_domain
}

# The aws_s3_bucket_public_access_block resource configures the bucket to block public access.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# The aws_s3_bucket_website_configuration resource configures the bucket to serve static files.
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# The aws_s3_bucket_ownership_controls resource configures the bucket to use bucket owner preferred object ownership.
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# The aws_s3_bucket_acl resource configures the bucket to be publicly readable.
resource "aws_s3_bucket_acl" "site" {
  bucket = aws_s3_bucket.site.id

  acl = "public-read"
  depends_on = [
    aws_s3_bucket_ownership_controls.site,
    aws_s3_bucket_public_access_block.site
  ]
}

# The aws_s3_bucket_policy resource configures the bucket to allow public read access.
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          aws_s3_bucket.site.arn,
          "${aws_s3_bucket.site.arn}/*",
        ]
      },
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.site
  ]
}

# The cloudflare_zones data source retrieves the zone ID for the specified domain.
data "cloudflare_zones" "domain" {
  filter {
    name = var.site_domain
  }
}

# The cloudflare_record resource creates a DNS record for the specified domain.
resource "cloudflare_record" "site_cname" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name    = var.site_domain
  value   = aws_s3_bucket_website_configuration.site.website_endpoint
  type    = "CNAME"

  ttl     = 1
  proxied = true
}

# The cloudflare_record resource creates a DNS record for the specified domain.
resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zones.domain.zones[0].id
  name    = "www"
  value   = var.site_domain
  type    = "CNAME"

  ttl     = 1
  proxied = true
}