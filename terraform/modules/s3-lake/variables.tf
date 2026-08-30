variable "bucket_name" {
  description = "Globally-unique name for the data lake bucket."
  type        = string
}

variable "force_destroy" {
  description = "Allow `terraform destroy` to empty + delete the bucket (learning project only)."
  type        = bool
  default     = true
}

variable "athena_results_prefix" {
  description = "Prefix whose objects (query results) are auto-expired."
  type        = string
  default     = "athena-results/"
}

variable "results_expiration_days" {
  description = "Days after which Athena results expire."
  type        = number
  default     = 7
}

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-KMS encryption (P30). Empty = SSE-S3 (AES256)."
  type        = string
  default     = ""
}
