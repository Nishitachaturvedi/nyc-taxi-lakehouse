-- ════════════════════════════════════════════════════════════════════════════
-- P20 — UNLOAD: export query results from Redshift back to S3 (Parquet), in
-- parallel. Useful to push curated results to the lake / share with other engines,
-- and as portfolio "evidence" before you tear Redshift down.
-- Replace <LAKE_BUCKET> and <REDSHIFT_ROLE_ARN>.
-- ════════════════════════════════════════════════════════════════════════════

UNLOAD ('
  SELECT z.borough,
         count(*)                       AS trips,
         round(sum(f.total_amount), 2)  AS revenue
  FROM fact_trips f
  JOIN dim_zone z ON f.pulocationid = z.location_id
  GROUP BY z.borough
')
TO 's3://<LAKE_BUCKET>/gold/redshift_unload/borough_revenue_'
IAM_ROLE '<REDSHIFT_ROLE_ARN>'
FORMAT AS PARQUET
ALLOWOVERWRITE;

-- Notes:
--   * UNLOAD writes multiple files in parallel (one per slice) by default; add
--     PARALLEL OFF for a single file, or PARTITION BY (col) to fan out by a column.
--   * The exported Parquet is immediately queryable by Athena/Spectrum/Glue.
--   * Then DESTROY Redshift (set enable_redshift=false, terraform apply) — the
--     UNLOADed results persist cheaply in S3.
