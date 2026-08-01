locals {
  common_tags = {
    project = var.project_name
    managed_by = "terraform"
    env = "learning"
  }  

  account_id = data.aws_caller_identity.current.account_id
}