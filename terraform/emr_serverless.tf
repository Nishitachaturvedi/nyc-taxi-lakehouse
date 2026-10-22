###############################################################################
# emr_serverless.tf — an EMR Serverless Spark application (P16). Cost-tuned:
# NO pre-initialized (warm) capacity, auto-stop after 15 min idle, capped max
# capacity. EMR Serverless bills ONLY while a job runs (no idle cluster cost).
###############################################################################

# IAM role the EMR job runs as.
resource "aws_iam_role" "emr_job" {
  name = "${var.project_name}-emr-job"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "emr-serverless.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Access to the lake bucket + read the Glue Data Catalog.
resource "aws_iam_role_policy" "emr_job_access" {
  name = "lake-and-glue"
  role = aws_iam_role.emr_job.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [module.lake.bucket_arn, "${module.lake.bucket_arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase", "glue:GetTable", "glue:GetPartitions",
          "glue:CreateTable", "glue:UpdateTable"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_emrserverless_application" "spark" {
  name          = "${var.project_name}-spark"
  release_label = "emr-7.1.0"
  type          = "spark"

  auto_start_configuration {
    enabled = true # start on demand when a job is submitted
  }

  # Stop the application after 15 min idle so you never pay for nothing.
  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = 15
  }

  # Cap autoscaling so a runaway job can't scale wide.
  maximum_capacity {
    cpu    = "8 vCPU"
    memory = "32 GB"
  }
  # NOTE: no `initial_capacity` block => no pre-initialized (warm) workers => no idle cost.
}
