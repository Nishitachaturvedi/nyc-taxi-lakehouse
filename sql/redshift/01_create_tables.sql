-- ════════════════════════════════════════════════════════════════════════════
-- P19 — Redshift tables with DISTRIBUTION + SORT keys (the core Redshift skill).
-- Run in the Redshift Serverless query editor (database: analytics).
--
-- DISTRIBUTION controls how rows spread across compute slices:
--   DISTSTYLE ALL  -> copy the whole table to every node (great for SMALL dims;
--                     makes joins to it shuffle-free).
--   DISTKEY(col)   -> co-locate rows by col so joins/aggregations on col avoid
--                     network movement (use the column you JOIN on most).
--   DISTSTYLE EVEN -> round-robin (default-ish; fine when no clear join key).
-- SORT keys keep data ordered on disk so range filters skip blocks (zone maps).
-- ════════════════════════════════════════════════════════════════════════════

-- Small dimension -> replicate to every node for fast, shuffle-free joins.
CREATE TABLE dim_zone (
    location_id  INTEGER,
    borough      VARCHAR(64),
    zone         VARCHAR(128),
    service_zone VARCHAR(64)
)
DISTSTYLE ALL;

-- Large fact -> DISTKEY on the most-joined column (pickup location), and a
-- COMPOUND SORTKEY on the timestamp so date-range queries scan fewer blocks.
-- Columns match the silver parquet so COPY maps by name.
CREATE TABLE fact_trips (
    vendorid         INTEGER,
    pickup_datetime  TIMESTAMP,
    dropoff_datetime TIMESTAMP,
    passenger_count  BIGINT,
    trip_distance    DOUBLE PRECISION,
    pulocationid     INTEGER,
    dolocationid     INTEGER,
    payment_type     BIGINT,
    fare_amount      DOUBLE PRECISION,
    tip_amount       DOUBLE PRECISION,
    total_amount     DOUBLE PRECISION
)
DISTKEY (pulocationid)
COMPOUND SORTKEY (pickup_datetime);

-- Rationale to say in interviews:
--   * dim_zone is tiny -> DISTSTYLE ALL removes the join shuffle entirely.
--   * fact is large + usually joined on location -> DISTKEY(pulocationid) co-locates
--     matching rows; if we mostly joined on date we'd reconsider.
--   * queries filter by time -> SORTKEY(pickup_datetime) enables zone-map block skipping.
--   * Modern Redshift can also AUTO choose dist/sort; knowing the manual choices matters.
