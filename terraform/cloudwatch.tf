###############################################################################
# cloudwatch.tf — log RETENTION = cost control. By default CloudWatch log groups
# keep logs forever (storage creeps up). We pin short retention on what we create.
# (Glue job log retention + dashboards/alarms are built out in the observability
#  lesson, P29. We pre-create the Lambda log group here so it has retention from
#  the first invocation.)
###############################################################################

resource "aws_cloudwatch_log_group" "lambda_validate" {
  name              = "/aws/lambda/${aws_lambda_function.validate_bronze.function_name}"
  retention_in_days = 7
}

/*  ── DISABLED until P21/P29 ──────────────────────────────────────────────────
    These alarms + dashboard reference resources you build later:
      - aws_sfn_state_machine.pipeline  created at P21 (Step Functions)
      - aws_sns_topic.pipeline          the alert topic (P21/P29)
    When you reach those lessons and declare them, remove the block-comment
    markers (the opening line above and the closing one at the bottom).
──────────────────────────────────────────────────────────────────────────────

# ── P29: alarms (email via the pipeline SNS topic) ───────────────────────────
# Pipeline failure: any failed Step Functions execution.
resource "aws_cloudwatch_metric_alarm" "pipeline_failed" {
  alarm_name          = "${var.project_name}-pipeline-failed"
  namespace           = "AWS/States"
  metric_name         = "ExecutionsFailed"
  dimensions          = { StateMachineArn = aws_sfn_state_machine.pipeline.arn }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.pipeline.arn]
  treat_missing_data  = "notBreaching"
}

# Lambda validation errors.
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-validate-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.validate_bronze.function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_actions       = [aws_sns_topic.pipeline.arn]
  treat_missing_data  = "notBreaching"
}

# ── P29: a dashboard (pipeline + Lambda health at a glance) ──────────────────
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.project_name
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          title  = "Pipeline executions",
          region = var.aws_region, stat = "Sum", period = 300,
          metrics = [
            ["AWS/States", "ExecutionsSucceeded", "StateMachineArn", aws_sfn_state_machine.pipeline.arn],
            ["AWS/States", "ExecutionsFailed", "StateMachineArn", aws_sfn_state_machine.pipeline.arn]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = {
          title  = "Lambda validate (invocations vs errors)",
          region = var.aws_region, stat = "Sum", period = 300,
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.validate_bronze.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.validate_bronze.function_name]
          ]
        }
      }
    ]
  })
}
*/
