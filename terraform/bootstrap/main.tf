
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      project    = var.project_name
      managed_by = "terraform-bootstrap"
    }
  }
}

variable "project_name" {
  type    = string
  default = "tlc-lakehouse"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Your account id — used to make the state bucket name globally unique.
data "aws_caller_identity" "current" {}

# ── The remote-state bucket ──────────────────────────────────────────────────
resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  # State is precious but for a learning project we allow teardown. In a real job
  # you would set force_destroy = false and add prevent_destroy.
  force_destroy = true
}

# Keep a history of state files (lets you recover from a bad apply).
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest (it can contain sensitive values).
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Never allow public access to state.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── The state lock table ─────────────────────────────────────────────────────
# Prevents two people (or two terminals) from applying at the same time and
# corrupting state. PAY_PER_REQUEST = no fixed cost, pennies at this scale.
resource "aws_dynamodb_table" "tf_lock" {
  name         = "${var.project_name}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" {
  description = "Paste this into ../backend.tf as the `bucket` value."
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table" {
  description = "DynamoDB table for state locking (already referenced in ../backend.tf)."
  value       = aws_dynamodb_table.tf_lock.name
}
