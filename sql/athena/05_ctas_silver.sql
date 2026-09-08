-- ════════════════════════════════════════════════════════════════════════════
-- P10 — CTAS (CREATE TABLE AS SELECT): use Athena itself as a lightweight ETL to
-- build a cleaned, optimized SILVER table (Parquet + partitioned) from bronze.
-- This is "ELT": transform in place, writing results back to the lake.
-- NOTE: partition columns must be LAST in the SELECT list, in partitioned_by order.
-- Re-run note: CTAS fails if the table exists — DROP first, or use INSERT INTO to
-- append (incremental, P17).
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE nyc_taxi.silver_yellow_trips
WITH (
  format              = 'PARQUET',
  parquet_compression = 'SNAPPY',
  partitioned_by      = ARRAY['year', 'month'],
  external_location   = 's3://tlc-lakehouse-lake-146697354523/silver/yellow_trips/'
) AS
SELECT
  vendorid,
  tpep_pickup_datetime  AS pickup_datetime,
  tpep_dropoff_datetime AS dropoff_datetime,
  passenger_count,
  trip_distance,
  pulocationid,
  dolocationid,
  payment_type,
  fare_amount,
  tip_amount,
  total_amount,
  year,                          -- partition cols must come LAST, in array order
  month
FROM nyc_taxi.yellow_tripdata
WHERE fare_amount  >= 0          -- basic cleaning: drop obviously bad rows
  AND trip_distance >= 0
  AND total_amount  >= 0;
