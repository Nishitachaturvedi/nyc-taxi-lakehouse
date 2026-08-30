###############################################################################
# s3.tf — the data lake, created via the reusable ./modules/s3-lake module
# (refactored from inline resources on P6). One bucket holds the medallion
# layers as prefixes: bronze/ (raw), silver/ (clean), gold/ (modeled).
###############################################################################

module "lake" {
  source      = "./modules/s3-lake"
  bucket_name = "${var.project_name}-lake-${local.account_id}"
  # force_destroy defaults to true (learning project).
  # kms_key_arn left empty => SSE-S3 (AES256). Upgraded to SSE-KMS on P30.
}

# ── moved {} blocks: the SAFE refactor technique ──────────────────────────────
# These tell Terraform each resource only changed ADDRESS (from the old flat
# s3.tf into the module) — it is NOT a destroy+recreate. This preserves the
# existing bucket and the bronze data already in it. Without these, Terraform
# would delete the old-address bucket and make a new one (losing data).
moved {
  from = aws_s3_bucket.lake
  to   = module.lake.aws_s3_bucket.lake
}
moved {
  from = aws_s3_bucket_versioning.lake
  to   = module.lake.aws_s3_bucket_versioning.lake
}
moved {
  from = aws_s3_bucket_public_access_block.lake
  to   = module.lake.aws_s3_bucket_public_access_block.lake
}
moved {
  from = aws_s3_bucket_server_side_encryption_configuration.lake
  to   = module.lake.aws_s3_bucket_server_side_encryption_configuration.lake
}
moved {
  from = aws_s3_bucket_lifecycle_configuration.lake
  to   = module.lake.aws_s3_bucket_lifecycle_configuration.lake
}
