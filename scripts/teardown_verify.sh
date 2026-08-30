#!/usr/bin/env bash
###############################################################################
# teardown_verify.sh — after `terraform destroy`, double-check that none of the
# usual "surprise bill" resources are still alive. Run via `make teardown`.
#
# This is your end-of-session safety net. If anything below prints an ID,
# delete it (each AWS lesson's "Teardown" section says how).
# (Expanded as the project adds services; safe to run anytime.)
###############################################################################
set -uo pipefail   # NOT -e: we want every check to run even if one errors

check() {
  local label="$1"; shift
  echo "• ${label}:"
  local out
  out="$("$@" 2>/dev/null || true)"
  if [ -z "${out}" ] || [ "${out}" = "None" ]; then
    echo "    ✓ none"
  else
    echo "    ⚠ FOUND -> ${out}"
  fi
}

echo "=== Teardown verification (anything ⚠ should be deleted) ==="

check "NAT gateways (must be none — ~\$32/mo each)" \
  aws ec2 describe-nat-gateways --filter Name=state,Values=available \
  --query 'NatGateways[].NatGatewayId' --output text

check "Glue interactive sessions (bill while alive)" \
  aws glue list-sessions --query 'Ids' --output text

check "Kinesis data streams (provisioned shards bill 24/7)" \
  aws kinesis list-streams --query 'StreamNames' --output text

check "Redshift Serverless workgroups" \
  aws redshift-serverless list-workgroups --query 'workgroups[].workgroupName' --output text

check "EMR Serverless applications" \
  aws emr-serverless list-applications --query 'applications[].id' --output text

echo ""
echo "Also: open Cost Explorer (daily view) — yesterday's spend should trend to ~\$0."
echo "Tip: log groups should have a retention set (we configure this in CloudWatch lessons)."
