###############################################################################
# backend.tf — store Terraform state remotely in S3, with DynamoDB locking.
#
# WHY: by default, state lives in a local terraform.tfstate file. A remote S3
# backend keeps it safe, shareable, and locked (so two applies can't clash).
#
# HOW TO USE (one-time, after running terraform/bootstrap):
#   1. Run the bootstrap config to create the state bucket + lock table.
#   2. Replace the `bucket` value below with the bootstrap's `state_bucket` output
#      (it includes your account id).
#   3. Run `terraform init` here — it will offer to copy state to S3. Say yes.
#
# Backend blocks CANNOT use variables, so the bucket name is hard-coded (this is
# normal for Terraform). For local validation only, we skip the backend with
# `terraform init -backend=false`.
###############################################################################
terraform {
  backend "s3" {
    # 👇 Replace <ACCOUNT_ID> with your 12-digit account id (from bootstrap output).
    bucket         = "tlc-lakehouse-tfstate-146697354523"
    key            = "main/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tlc-lakehouse-tflock"
    encrypt        = true
  }
}
