###############################################################################
# redshift.tf — Redshift Serverless data warehouse (P19/P20).
#
# COST-SAFE DESIGN: the namespace/workgroup are gated behind var.enable_redshift
# (count = ...). Redshift Serverless STORAGE bills 24/7, so you flip this ON only
# for the focused session and OFF again afterward (which deletes it). A usage limit
# also hard-caps RPU-hours. Use the $300/90-day Redshift free trial if available.
###############################################################################

# Default VPC subnets — Redshift Serverless needs subnets across AZs. The default
# VPC is free and needs NO NAT gateway (we never create one).
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for the workgroup (free; egress only).
resource "aws_security_group" "redshift" {
  name        = "${var.project_name}-redshift"
  description = "Redshift Serverless workgroup"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM role Redshift assumes for COPY / UNLOAD / Spectrum (S3 + Glue catalog). Free.
resource "aws_iam_role" "redshift" {
  name = "${var.project_name}-redshift"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "redshift.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "redshift_access" {
  name = "lake-and-glue"
  role = aws_iam_role.redshift.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
        Resource = [module.lake.bucket_arn, "${module.lake.bucket_arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase", "glue:GetDatabases", "glue:GetTable", "glue:GetTables",
          "glue:GetPartition", "glue:GetPartitions", "glue:BatchGetPartition"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── The warehouse (gated by enable_redshift) ─────────────────────────────────
resource "aws_redshiftserverless_namespace" "main" {
  count                = var.enable_redshift ? 1 : 0
  namespace_name       = "${var.project_name}-ns"
  admin_username       = "admin"
  admin_user_password  = var.redshift_admin_password
  db_name              = "analytics"
  iam_roles            = [aws_iam_role.redshift.arn]
  default_iam_role_arn = aws_iam_role.redshift.arn
}

resource "aws_redshiftserverless_workgroup" "main" {
  count          = var.enable_redshift ? 1 : 0
  workgroup_name = "${var.project_name}-wg"
  namespace_name = aws_redshiftserverless_namespace.main[0].namespace_name

  # COST: base_capacity is in RPU. 8 is the safe minimum everywhere; in us-east-1
  # you can lower to 4 (cheaper) if your account/region supports it.
  base_capacity       = 8
  publicly_accessible = false
  subnet_ids          = data.aws_subnets.default.ids
  security_group_ids  = [aws_security_group.redshift.id]
}

# HARD cost cap: limit monthly RPU-hours and TURN OFF queries when exceeded.
resource "aws_redshiftserverless_usage_limit" "rpu" {
  count         = var.enable_redshift ? 1 : 0
  resource_arn  = aws_redshiftserverless_workgroup.main[0].arn
  usage_type    = "serverless-compute"
  amount        = 10 # RPU-hours per month
  period        = "monthly"
  breach_action = "deactivate" # stop running user queries past the cap
}
