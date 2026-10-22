###############################################################################
# dynamodb.tf — a tiny watermark (high-water-mark) table for incremental loads (P17).
# Stores, per source table, the last-processed value (e.g. "2024-02") so the job
# processes only newer data. PAY_PER_REQUEST = no fixed cost, pennies at this scale.
###############################################################################
resource "aws_dynamodb_table" "watermark" {
  name         = "${var.project_name}-watermark"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "table_name"

  attribute {
    name = "table_name"
    type = "S"
  }
}
