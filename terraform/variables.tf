variable "project_name" {
    description = "Short name prefix for all resources (lowercase, no spaces)."
    type = string
    default = "tlc-lakehouse"
}

variable "aws_region" {
    description ="AWS region for everything. us-east-1 is cheapest with all features."
    type = string
    default = "us-east-1"
}

variable "alert_email" {
    description = "Email address that receives budget + cost-anomaly alerts."
    type = string
}

variable "monthly_budget_usd" {
    description = "Monthly cost budget; alerts fire at 50/80/100% of this."
    type = number
    default = 30
}

variable "daily_budget_usd" {
    description = "Daily cost budget; an alert fires if a single day exceeds this (early warning for a forgotten resource)."
    type = number
    default = 3
}

variable "enable_redshift" {
    description = "Create Redshift Serverless? Keep false except during the P19/P20 session."
    type = bool
    default = false
}

variable "redshift_admin_password" {
    description = "Redshift admin password (set in terraform.tfvars for the session; moved to Secrets Manager on P30). Must meet Redshift complexity rules (8-64 chars, upper+lower+number)."
    type = string
    sensitive = true
    default = ""

}

variable "enable_streaming" {
    description = "Create Kinesis + Firehose? Keep false except during the P25/P26 session."
    type = bool
    default = false

}