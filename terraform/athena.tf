resource "aws_athena_workgroup" "main" {
  name = "${var.project_name}-wg"


  configuration {
    # false = workgroup settings are DEFAULTS (still applied to normal queries),
    # but a CTAS may write to its own external_location (e.g. silver/). With `true`,
    # Athena blocks external_location and forces all output to athena-results/.
    enforce_workgroup_configuration    = false
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
