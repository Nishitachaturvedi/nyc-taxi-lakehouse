select
cast(locationid as integer) as location_id,
borough,
zone,
service_zone
from {{ source('nyc_taxi', 'taxi_zone_lookup') }} 