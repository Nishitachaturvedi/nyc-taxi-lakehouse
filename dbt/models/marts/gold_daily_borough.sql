-- Mart (gold): business-ready daily revenue per borough.
-- The ref() calls below build the dependency graph: dbt runs staging models first.
select
    date(t.pickup_datetime)         as trip_date,
    z.borough,
    count(*)                        as trips,
    round(sum(t.total_amount), 2)   as revenue,
    round(avg(t.fare_amount), 2)    as avg_fare
from {{ ref('stg_yellow_tripdata') }} t
join {{ ref('stg_taxi_zone_lookup') }} z
    on t.pulocationid = z.location_id
where t.fare_amount > 0
group by
    date(t.pickup_datetime),
    z.borough
