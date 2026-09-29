# dbt — NYC Taxi Lakehouse transforms

A dbt project that models the silver/gold layers on **Athena** (dbt-athena adapter).
Same transform logic as the hand-written CTAS, but managed with dependency ordering,
tests, and lineage docs.

## Layout
- `models/sources.yml` — declares the raw bronze tables (crawler-made).
- `models/staging/` — cleaned staging **views** over bronze (`stg_*`).
- `models/marts/` — business-ready **gold** table (`gold_daily_borough`).
- `*.yml` — model descriptions + data-quality tests (`not_null`, `unique`).

## Run
```bash
pip install dbt-athena-community
cp profiles.yml.example ~/.dbt/profiles.yml   # then set <LAKE_BUCKET>
dbt debug                              # test the Athena connection
dbt run                                # build staging views + gold table (in DAG order)
dbt test                               # run data-quality tests
dbt docs generate && dbt docs serve    # browse the lineage graph
```
