import sys
from pyspark.sql import SparkSession
from pyspark.sql import functions as F

lake = sys.argv[1] if len(sys.argv) > 1 else "s3://CHANGE-ME-lake-bucket"

spark = SparkSession.builder.appName("emr_bronze_to_silver").getOrCreate()

df = spark.read.parquet(f"{lake}/bronze/yellow_tripdata/")

silver = df.filter(
    (F.col("fare_amount") >= 0)
    & (F.col("total_amount") >= 0)
    & (F.col("trip_distance") >= 0)
)

final = (
    silver
    .withColumnRenamed("tpep_pickup_datetime", "pickup_datetime")
    .withColumnRenamed("tpep_dropoff_datetime", "dropoff_datetime")
    .dropDuplicates()
)

final.write.mode("append").partitionBy("year", "month").parquet(f"{lake}/silver/yellow_trips_emr/")

spark.stop()
