###############################################################################
# step_functions.tf — orchestrate the batch pipeline (P21): crawl -> Glue job ->
# notify, with retries/backoff/catch. Step Functions Standard Workflows are in the
# free tier (4,000 transitions/month) — our pipeline is well within it.
###############################################################################

# SNS topic for pipeline notifications (success/failure) -> your email.
resource "aws_sns_topic" "pipeline" {
  name = "${var.project_name}-pipeline"
}

resource "aws_sns_topic_subscription" "pipeline_email" {
  topic_arn = aws_sns_topic.pipeline.arn
  protocol  = "email"
  endpoint  = var.alert_email # confirm the subscription via the email AWS sends
}

# Role the state machine assumes.
resource "aws_iam_role" "sfn" {
  name = "${var.project_name}-sfn"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "sfn" {
  name = "orchestrate"
  role = aws_iam_role.sfn.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["glue:StartJobRun", "glue:GetJobRun", "glue:GetJobRuns", "glue:BatchStopJobRun"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["glue:StartCrawler", "glue:GetCrawler"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.pipeline.arn
      }
    ]
  })
}

# The state machine. templatefile() injects the real resource names into the ASL.
resource "aws_sfn_state_machine" "pipeline" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.sfn.arn
  type     = "STANDARD"

  definition = templatefile("${path.module}/../src/stepfunctions/pipeline.asl.json", {
    crawler_name  = aws_glue_crawler.bronze.name
    glue_job_name = aws_glue_job.bronze_to_silver.name
    sns_topic_arn = aws_sns_topic.pipeline.arn
  })
}
