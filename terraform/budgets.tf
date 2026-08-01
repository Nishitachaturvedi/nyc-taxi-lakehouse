###############################################################################
# budgets.tf — THE most important file in this project for your wallet.
# Creates AWS Budgets + Cost Anomaly Detection so you get an email BEFORE a
# forgotten resource becomes a real bill. Apply this on day P1, before anything else.
###############################################################################

# ── Monthly cost budget: email at 50%, 80%, 100% (actual) + 100% (forecasted) ─
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Three actual-spend thresholds via a dynamic block (DRY).
  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.alert_email]
    }
  }

  # Forecasted overrun warns you EARLY (AWS predicts you'll exceed the budget).
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}

# ── Daily budget: the single best early warning for "I forgot to destroy X" ───
resource "aws_budgets_budget" "daily" {
  name         = "${var.project_name}-daily"
  budget_type  = "COST"
  limit_amount = tostring(var.daily_budget_usd)
  limit_unit   = "USD"
  time_unit    = "DAILY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

# ── Cost Anomaly Detection: AWS ML flags unexpected spend spikes per service ──
resource "aws_ce_anomaly_monitor" "services" {
  name              = "${var.project_name}-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "alerts" {
  name             = "${var.project_name}-anomaly-sub"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.services.arn]

  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  # Alert when an anomaly's total impact is >= $5 (catch issues while still cheap).
  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["5"]
    }
  }
}
