output "bucket" {
  description = "The data lake bucket name."
  value       = aws_s3_bucket.lake.bucket
}

output "bucket_arn" {
  description = "The data lake bucket ARN (for IAM policies)."
  value       = aws_s3_bucket.lake.arn
}

output "bucket_id" {
  description = "The data lake bucket id."
  value       = aws_s3_bucket.lake.id
}
