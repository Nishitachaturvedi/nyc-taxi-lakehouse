-- ════════════════════════════════════════════════════════════════════════════
-- P20 — Redshift Spectrum: query the S3 LAKE directly from Redshift (no load),
-- and join lake (cold) data to warehouse (hot) tables. Replace <REDSHIFT_ROLE_ARN>.
-- Spectrum reads the Glue Data Catalog and scans S3 (billed like Athena, $5/TB).
-- ════════════════════════════════════════════════════════════════════════════

-- Create an external schema mapped to our Glue database (nyc_taxi).
CREATE EXTERNAL SCHEMA IF NOT EXISTS spectrum
FROM DATA CATALOG
DATABASE 'nyc_taxi'
IAM_ROLE '<REDSHIFT_ROLE_ARN>';

-- Query lake data WITHOUT loading it (partition pruning still applies):
SELECT count(*) AS jan_trips
FROM spectrum.bronze_yellow_trips
WHERE year = '2024' AND month = '01';

-- HOT + COLD tiering: join loaded warehouse data (fact_trips) to lake data via
-- Spectrum in one query — keep hot data in Redshift, leave cold history in S3.
SELECT z.borough,
       count(*)            AS warehouse_trips,
       round(sum(f.total_amount), 2) AS revenue
FROM fact_trips f
JOIN dim_zone z ON f.pulocationid = z.location_id
GROUP BY z.borough
ORDER BY revenue DESC;

-- Interview point — when to load vs Spectrum:
--   * Load (COPY) the HOT, frequently-queried data into Redshift for speed.
--   * Leave COLD/rarely-queried history in S3, query on demand via Spectrum.
--   * This "lake + warehouse" tiering balances performance and cost (RA3/Serverless
--     + Spectrum is the canonical pattern).
