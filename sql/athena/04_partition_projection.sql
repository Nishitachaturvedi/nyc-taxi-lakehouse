-- ════════════════════════════════════════════════════════════════════════════
-- P10 — Partition PROJECTION: let Athena COMPUTE partitions from a pattern, so you
-- never run a crawler or MSCK REPAIR again. Great for predictable date layouts and
-- tables with huge numbers of partitions (faster planning, lower cost, no crawler).
-- ════════════════════════════════════════════════════════════════════════════

CREATE EXTERNAL TABLE IF NOT EXISTS nyc_taxi.bronze_yellow_trips_proj (
  vendorid              int,
  tpep_pickup_datetime  timestamp,
  tpep_dropoff_datetime timestamp,
  passenger_count       bigint,
  trip_distance         double,
  ratecodeid            bigint,
  store_and_fwd_flag    string,
  pulocationid          int,
  dolocationid          int,
  payment_type          bigint,
  fare_amount           double,
  extra                 double,
  mta_tax               double,
  tip_amount            double,
  tolls_amount          double,
  improvement_surcharge double,
  total_amount          double,
  congestion_surcharge  double,
  airport_fee           double
)
PARTITIONED BY (year string, month string)
STORED AS PARQUET
LOCATION 's3://tlc-lakehouse-lake-146697354523/bronze/yellow_tripdata/'
TBLPROPERTIES (
  'projection.enabled'        = 'true',
  'projection.year.type'      = 'integer',
  'projection.year.range'     = '2022,2025',
  'projection.month.type'     = 'integer',
  'projection.month.range'    = '1,12',
  'projection.month.digits'   = '2',
  'storage.location.template' = 's3://tlc-lakehouse-lake-146697354523/bronze/yellow_tripdata/year=${year}/month=${month}'
);

-- No MSCK / crawler needed — query immediately. Athena derives the partitions:
SELECT count(*) AS jan_trips
FROM nyc_taxi.bronze_yellow_trips_proj
WHERE year = '2024' AND month = '01';
