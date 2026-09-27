-- ════════════════════════════════════════════════════════════════════════════
-- P11 — Build DIMENSION tables for the gold star schema (CTAS to Parquet).
-- ════════════════════════════════════════════════════════════════════════════

-- dim_zone: clean, typed location dimension (key matches the fact's int FK).
CREATE TABLE nyc_taxi.dim_zone
WITH (format = 'PARQUET', external_location = 's3://tlc-lakehouse-lake-146697354523/gold/dim_zone/') AS
SELECT
  CAST(locationid AS int) AS location_id,   -- business key for the dimension
  borough,
  zone,
  service_zone
FROM nyc_taxi.taxi_zone_lookup;

-- dim_payment: small static dimension decoding payment_type codes -> labels.
CREATE TABLE nyc_taxi.dim_payment
WITH (format = 'PARQUET', external_location = 's3://tlc-lakehouse-lake-146697354523/gold/dim_payment/') AS
SELECT * FROM (
  VALUES
    (1, 'Credit card'),
    (2, 'Cash'),
    (3, 'No charge'),
    (4, 'Dispute'),
    (5, 'Unknown'),
    (6, 'Voided trip')
) AS t (payment_type, payment_label);
