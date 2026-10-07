###############################################################################
# glue_job.tf — the bronze->silver Glue ETL job (P13). Cost-tuned: 2 G.1X workers,
# FLEX execution (~34% cheaper), bookmarks on. The PySpark script lives in src/glue
# and is uploaded to S3 here.
###############################################################################

# ── IAM role the Glue job runs as ────────────────────────────────────────────
resource "aws_iam_role" "glue_job" {
  name = "${var.project_name}-glue-job"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_job_service" {
  role       = aws_iam_role.glue_job.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Read + write only OUR lake bucket (least privilege).
resource "aws_iam_role_policy" "glue_job_s3" {
  name = "lake-read-write"
  role = aws_iam_role.glue_job.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [module.lake.bucket_arn, "${module.lake.bucket_arn}/*"]
    }]
  })
}

# ── Upload the job script to S3 ──────────────────────────────────────────────
resource "aws_s3_object" "bronze_to_silver_script" {
  bucket = module.lake.bucket
  key    = "scripts/glue/bronze_to_silver.py"
  source = "${path.module}/../src/glue/bronze_to_silver.py"
  etag   = filemd5("${path.module}/../src/glue/bronze_to_silver.py")
}

# ── The Glue job ─────────────────────────────────────────────────────────────
resource "aws_glue_job" "bronze_to_silver" {
  name              = "${var.project_name}-bronze-to-silver"
  role_arn          = aws_iam_role.glue_job.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2      # minimum for Spark; cheap
  execution_class   = "FLEX" # delay-tolerant batch -> ~34% cheaper
  max_retries       = 0

  command {
    name            = "glueetl"
    script_location = "s3://${module.lake.bucket}/scripts/glue/bronze_to_silver.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-bookmark-option"              = "job-bookmark-enable"
    "--lake_bucket"                      = module.lake.bucket
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--TempDir"                          = "s3://${module.lake.bucket}/tmp/"
  }
}
