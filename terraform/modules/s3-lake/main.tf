###############################################################################
# modules/s3-lake — a REUSABLE data-lake bucket.
# Refactored from the flat s3.tf on P6 so the same bucket pattern can be reused
# (and so the config reads like building blocks). Modules are how real Terraform
# codebases stay DRY and testable.
###############################################################################

resource "aws_s3_bucket" "lake" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

resource "aws_s3_bucket_versioning" "lake" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default {
      # SSE-KMS when a key is provided (P30), else free SSE-S3.
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
    # Bucket keys cut KMS request costs for high-volume access.
    bucket_key_enabled = var.kms_key_arn != "" ? true : null
  }
}

# Defense-in-depth: deny any non-TLS (plaintext HTTP) access to the lake (P30).
resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.lake.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.lake.arn, "${aws_s3_bucket.lake.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "lake" {
  bucket = aws_s3_bucket.lake.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "expire-athena-results"
    status = "Enabled"
    filter {
      prefix = var.athena_results_prefix
    }
    expiration {
      days = var.results_expiration_days
    }
  }
}
