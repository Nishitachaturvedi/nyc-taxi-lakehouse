import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.sql import functions as F
from pyspark.context import SparkContext

args = getResolvedOptions(sys.argv, ["JOB_NAME","lake_bucket"])
lake = args["lake_bucket"]

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
job = Job(glue_context)
job.init(args["JOB_NAME"], args)


bronze_dyf = glue_context.create_dynamic_frame.from_catalog(

database ="nyc_taxi",
table_name = "yellow_tripdata",
transformation_ctx = "yellow_tripdata",

)
df =bronze_dyf.toDF()

silver = (df.filter((F.col("fare_amount") >= 0) & (F.col("trip_distance")>=0) & (F.col("total_amount")>=0)).withColumnRenamed("tpep_pickup_datetime", "pickup_datetime")
          .withColumnRenamed("tpep_dropoff_datetime", "dropoff_datetime").dropDuplicates()
          
          )

silver.write.mode("append").partitionBy("year", "month").parquet(f"s3://{lake}/silver/yellow_trips/")

job.commit()
