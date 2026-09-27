-- ════════════════════════════════════════════════════════════════════════════
-- P11 — GOLD layer: a business-ready aggregate fact, built from silver + dims.
-- Grain: one row per (trip_date, borough, payment_label).
-- Partition column (trip_month) must be LAST in the SELECT.
-- ════════════════════════════════════════════════════════════════════════════

CREATE TABLE nyc_taxi.gold_daily_borough
WITH (
  format            = 'PARQUET',
  partitioned_by    = ARRAY['trip_month'],
  external_location = 's3://tlc-lakehouse-lake-146697354523/gold/daily_borough/'
) AS
SELECT
  date(t.pickup_datetime)                 AS trip_date,
  z.borough,
  p.payment_label,
  count(*)                                AS trips,
  round(sum(t.total_amount), 2)           AS revenue,
  round(avg(t.fare_amount), 2)            AS avg_fare,
  round(avg(t.trip_distance), 2)          AS avg_distance,
  date_format(t.pickup_datetime, '%Y-%m') AS trip_month   -- partition col, LAST
FROM nyc_taxi.silver_yellow_trips t
JOIN      nyc_taxi.dim_zone    z ON t.pulocationid = z.location_id
LEFT JOIN nyc_taxi.dim_payment p ON t.payment_type = p.payment_type
WHERE t.fare_amount > 0
GROUP BY
  date(t.pickup_datetime),
  z.borough,
  p.payment_label,
  date_format(t.pickup_datetime, '%Y-%m');

-- An analyst now queries this small, pre-joined table cheaply:
SELECT trip_date, borough, sum(revenue) AS revenue
FROM nyc_taxi.gold_daily_borough
WHERE trip_month = '2024-01'
GROUP BY trip_date, borough
ORDER BY revenue DESC
LIMIT 10;

-- Grain check (must return 0 rows):
SELECT trip_date, borough, payment_label, count(*)
FROM nyc_taxi.gold_daily_borough
GROUP BY trip_date, borough, payment_label
HAVING count(*) > 1;
