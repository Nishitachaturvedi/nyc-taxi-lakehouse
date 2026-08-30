###############################################################################
# outputs.tf — root-level outputs (values printed after apply / read by scripts).
###############################################################################

output "lake_bucket" {
  description = "Name of the data lake bucket."
  value       = module.lake.bucket # comes from the s3-lake module's `bucket` output
}
