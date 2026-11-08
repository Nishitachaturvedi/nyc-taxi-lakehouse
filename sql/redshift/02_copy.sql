-- ════════════════════════════════════════════════════════════════════════════
-- P19 — Load data into Redshift with COPY (the fast, parallel bulk loader).
-- Replace <LAKE_BUCKET> and <REDSHIFT_ROLE_ARN> (terraform: aws_iam_role.redshift.arn).
-- COPY reads MANY files in parallel across slices — far faster than INSERTs.
-- FORMAT AS PARQUET maps columns by NAME (our tables match the parquet names).
-- ════════════════════════════════════════════════════════════════════════════

-- Load the small zone dimension (from the gold parquet built on P11).
COPY dim_zone
FROM 's3://<LAKE_BUCKET>/gold/dim_zone/'
IAM_ROLE '<REDSHIFT_ROLE_ARN>'
FORMAT AS PARQUET;

-- Load the fact from the silver parquet (year=/month= are path partitions, not
-- file columns, so they aren't loaded — pickup_datetime carries the date).
COPY fact_trips
FROM 's3://<LAKE_BUCKET>/silver/yellow_trips/'
IAM_ROLE '<REDSHIFT_ROLE_ARN>'
FORMAT AS PARQUET;

-- Sanity checks:
SELECT count(*) AS zones FROM dim_zone;
SELECT count(*) AS trips FROM fact_trips;

-- Inspect distribution/sort effectiveness (interview-flex):
--   SVV_TABLE_INFO shows skew, sortkey, unsorted %, etc.
SELECT "table", diststyle, sortkey1, skew_rows, unsorted
FROM svv_table_info
WHERE "table" IN ('fact_trips', 'dim_zone');

-- COPY best practices to mention:
--   * Load from MANY files (one per slice multiple) for parallelism.
--   * Use columnar source (Parquet) so COPY is efficient.
--   * After big loads, ANALYZE (stats) and VACUUM (reclaim/sort) if needed
--     (Redshift often automates these now).
