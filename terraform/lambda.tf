###############################################################################
# lambda.tf — event-driven validation (P15). When an object lands in bronze/,
# S3 triggers this Lambda, which validates it. Lambda is in the always-free tier.
###############################################################################

# Zip the Lambda source at plan time (archive provider).
data "archive_file" "validate_bronze" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda/validate_bronze.py"
  output_path = "${path.module}/build/validate_bronze.zip"
}

resource "aws_iam_role" "lambda_validate" {
  name = "${var.project_name}-lambda-validate"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Basic execution role = permission to write CloudWatch logs.
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_validate.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "validate_bronze" {
  function_name    = "${var.project_name}-validate-bronze"
  role             = aws_iam_role.lambda_validate.arn
  runtime          = "python3.12"
  handler          = "validate_bronze.handler"
  filename         = data.archive_file.validate_bronze.output_path
  source_code_hash = data.archive_file.validate_bronze.output_base64sha256
  timeout          = 30
  memory_size      = 128
}

# Allow S3 to invoke the function.
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validate_bronze.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.lake.bucket_arn
}

# Wire up: new objects under bronze/ -> invoke the Lambda.
resource "aws_s3_bucket_notification" "bronze_events" {
  bucket = module.lake.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.validate_bronze.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "bronze/"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
