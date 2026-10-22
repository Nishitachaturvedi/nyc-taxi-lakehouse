###############################################################################
# glue_incremental.tf — the incremental bronze->silver Glue job (P17).
# Reuses the existing glue_job IAM role (from glue_job.tf) but adds DynamoDB
# access for the watermark. Passes --watermark_table so the script knows which
# DynamoDB table holds the high-water-mark.
###############################################################################

# ── Extra permission: let the Glue role read/write the watermark item ────────
resource "aws_iam_role_policy" "glue_job_dynamodb" {
  name = "watermark-access"
  role = aws_iam_role.glue_job.id # the SAME role created in glue_job.tf
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:PutItem"]
      Resource = aws_dynamodb_table.watermark.arn # the table from dynamodb.tf
    }]
  })
}

# ── Upload the incremental script to S3 ──────────────────────────────────────
resource "aws_s3_object" "incremental_load_script" {
  bucket = module.lake.bucket
  key    = "scripts/glue/incremental_load.py"
  source = "${path.module}/../src/glue/incremental_load.py"
  etag   = filemd5("${path.module}/../src/glue/incremental_load.py")
}

# ── The incremental Glue job ─────────────────────────────────────────────────
resource "aws_glue_job" "incremental_load" {
  name              = "${var.project_name}-incremental-load"
  role_arn          = aws_iam_role.glue_job.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  execution_class   = "FLEX"
  max_retries       = 0

  command {
    name            = "glueetl"
    script_location = "s3://${module.lake.bucket}/scripts/glue/incremental_load.py"
    python_version  = "3"
  }

  default_arguments = {
    "--lake_bucket"                      = module.lake.bucket
    "--watermark_table"                  = aws_dynamodb_table.watermark.name # extra arg for P17
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${module.lake.bucket}/tmp/"
  }
}
