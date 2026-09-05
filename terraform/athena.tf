resource "aws_athena_workgroup" "main" {
  name = "${var.project_name}-wg"


  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query      = 1073741824

    result_configuration {
      output_location = "s3://${module.lake.bucket}/athena-results/"
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }
  force_destroy = true
}
