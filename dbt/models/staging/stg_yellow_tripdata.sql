with src as (
    select * from {{ source('nyc_taxi', 'yellow_tripdata') }}
)

select 
vendorid,
tpep_pickup_datetime as pickup_datetime,
tpep_dropoff_datetime as dropoff_datetime,
passenger_count,
trip_distance,
pulocationid,
dolocationid,
payment_type,
fare_amount,
tip_amount,
total_amount,
year,
month
from src where fare_amount >= 0 and trip_distance >= 0

