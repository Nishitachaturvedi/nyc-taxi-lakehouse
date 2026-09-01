resource "aws_glue_catalog_database" "nyc_taxi" {
  name        = "nyc_taxi"
  description = "NYC taxi lakehouse - bronze/silver/gold tables."
}

resource "aws_iam_role" "glue_crawler" {
  name = "${var.project_name}-glue-crawler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_crawler_s3" {
  name = "lake-read"
  role = aws_iam_role.glue_crawler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [module.lake.bucket_arn, "${module.lake.bucket_arn}/*"]
    }]
  })
}

resource "aws_glue_crawler" "bronze" {
  name          = "${var.project_name}-bronze"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.nyc_taxi.name

  s3_target {
    path = "s3://${module.lake.bucket}/bronze/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }
}


