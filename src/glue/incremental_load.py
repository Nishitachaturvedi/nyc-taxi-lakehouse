import sys
import boto3
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.sql import functions as F
from pyspark.context import SparkContext


args = getResolvedOptions(sys.argv, ["JOB_NAME", "lake_bucket", "watermark_table"])
lake = args["lake_bucket"]
wm_table = args["watermark_table"]
SOURCE = "bronze_yellow_trips"

ddb = boto3.resource("dynamodb").Table(wm_table)
item = ddb.get_item(Key={"table_name":SOURCE}).get("Item", {})
last_watermark = item.get("watermark", "0000-00")

sc = SparkContext()
glue_context = GlueContext(sc)
spark = glue_context.spark_session
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
job = Job(glue_context)
job.init(args["JOB_NAME"], args)

df = spark.read.parquet(f"s3://{lake}/bronze/yellow_tripdata/")
df = df.withColumn("month", F.lpad(F.col("month").cast("string"),2,"0"))
df = df.withColumn("ym",F.concat_ws("-",F.col("year"),F.col("month")))
new = df.where(F.col("ym") > F.lit(last_watermark)).drop("ym")

if new.head(1):
    cleaned = new.where(
        (F.col("fare_amount") >= 0) & (F.col("trip_distance") >= 0)
    )

    cleaned.write.mode("overwrite").partitionBy("year", "month").parquet(f"s3://{lake}/silver/yellow_trips/")
    newest = new.select(F.max(F.concat_ws("-",F.col("year"),F.col("month")))).collect()[0][0]
    ddb.put_item(Item={"table_name":SOURCE,"watermark":newest})
    print(f"processed up to {newest} (was {last_watermark})")

else :
    print(f"no new partitions beyond watermark {last_watermark}")

job.commit()







