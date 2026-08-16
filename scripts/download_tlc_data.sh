#!/usr/bin/env bash
###############################################################################
# download_tlc_data.sh — download NYC TLC yellow-taxi months and upload them to
# the data lake's bronze/ prefix, in Hive-style partitions (year=/month=).
#
# Usage:
#   bash scripts/download_tlc_data.sh <lake-bucket> [YYYY-MM ...]
#   # default months: 2024-01 2024-02 2024-03
#
# Or via Make (auto-fills the bucket from terraform output):
#   make download-data
#
# Requires: AWS CLI configured (aws configure) + curl.
###############################################################################
set -euo pipefail

BUCKET="${1:-}"
if [ -z "$BUCKET" ]; then
  echo "Usage: $0 <lake-bucket> [YYYY-MM ...]"
  echo "Tip:   make download-data   (fills the bucket from terraform output)"
  exit 1
fi
shift || true

MONTHS=("$@")
if [ ${#MONTHS[@]} -eq 0 ]; then
  MONTHS=(2024-01 2024-02 2024-03)
fi

BASE="https://d37ci6vzurychx.cloudfront.net"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT   # always clean up the temp dir

for m in "${MONTHS[@]}"; do
  year="${m%-*}"      # 2024-01 -> 2024
  month="${m#*-}"     # 2024-01 -> 01
  file="yellow_tripdata_${m}.parquet"

  echo "↓ downloading ${file}"
  curl -L --fail --progress-bar -o "${TMP}/${file}" "${BASE}/trip-data/${file}"

  # Hive-style partition path so query engines can prune by year/month later.
  key="bronze/yellow_tripdata/year=${year}/month=${month}/${file}"
  echo "↑ uploading to s3://${BUCKET}/${key}"
  aws s3 cp "${TMP}/${file}" "s3://${BUCKET}/${key}"
done

echo "↓ downloading taxi_zone_lookup.csv"
curl -L --fail --progress-bar -o "${TMP}/taxi_zone_lookup.csv" "${BASE}/misc/taxi_zone_lookup.csv"
aws s3 cp "${TMP}/taxi_zone_lookup.csv" "s3://${BUCKET}/bronze/taxi_zone_lookup/taxi_zone_lookup.csv"

echo ""
echo "Done. bronze/ now contains:"
aws s3 ls "s3://${BUCKET}/bronze/" --recursive --human-readable
