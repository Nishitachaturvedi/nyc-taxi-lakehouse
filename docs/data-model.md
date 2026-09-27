# Gold Layer — Dimensional Data Model (Star Schema)

The **gold** layer models cleaned silver data as a **star schema** for fast, cheap,
business-ready analytics. It is built with Athena **CTAS** from `silver_yellow_trips`.

## Star schema

```
                 dim_payment
                     │
   dim_zone ── gold_daily_borough (fact)
```

- **Fact:** `gold_daily_borough` — an aggregate fact (measurable events, rolled up).
- **Dimensions:** `dim_zone`, `dim_payment` — descriptive context to slice/filter by.

## Grain

> **One row per (`trip_date`, `borough`, `payment_label`).**

Grain is defined first and verified with a grain check (`GROUP BY` the grain columns
`HAVING count(*) > 1` must return **0 rows** — no duplicates).

## Fact table — `gold_daily_borough`

| Column | Type | Notes |
|---|---|---|
| trip_date | date | grain: the day |
| borough | string | grain: from `dim_zone` |
| payment_label | string | grain: from `dim_payment` |
| trips | bigint | measure: count of trips |
| revenue | double | measure: sum(total_amount) |
| avg_fare | double | measure: avg(fare_amount) |
| avg_distance | double | measure: avg(trip_distance) |
| trip_month | string | **partition** ('YYYY-MM') |

Built by joining silver → `dim_zone` (INNER, on `pulocationid = location_id`) and
→ `dim_payment` (LEFT, so trips with an unknown payment code are not dropped),
filtered to `fare_amount > 0`, partitioned by `trip_month`.

## Dimensions

**`dim_zone`** — location dimension
| Column | Type | Notes |
|---|---|---|
| location_id | int | business key (matches fact FK) |
| borough | string | |
| zone | string | |
| service_zone | string | |

**`dim_payment`** — payment decode
| Column | Type | Notes |
|---|---|---|
| payment_type | int | code (1–6) |
| payment_label | string | human label |

## Design choices

- **Denormalized gold** — borough/payment labels are baked into the fact so dashboards
  read a single pre-aggregated table with no joins (fast + cheap on pay-per-scan Athena).
- **Aggregate fact** — pre-computed once; many consumers read a tiny table instead of
  re-scanning millions of silver rows.
- **Keys** — dimensions use the source business key (`location_id`) for this learning
  project; production would add a **surrogate key** (stable, enables SCD history).
- **SCD** — slowly-changing-dimension handling (Type 2 history) is added on P27.
