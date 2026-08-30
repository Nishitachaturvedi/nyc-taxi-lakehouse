"""
P5 — Apache Iceberg hands-on, NO Java/Spark required, using PyIceberg.

Demonstrates the "lakehouse" superpowers Iceberg adds on top of plain Parquet:
  1. ACID appends, each creating a SNAPSHOT
  2. TIME TRAVEL — query the table as of an earlier snapshot
  3. SCHEMA EVOLUTION — add a column without rewriting old data

Run from the repo root:  python3 src/iceberg/iceberg_demo.py
Requires:  pip install "pyiceberg[sql-sqlite,pyarrow]"

On AWS you'll create Iceberg tables via Athena/Glue (later weeks) backed by the
Glue Data Catalog + S3 — exactly the same concepts shown here locally.
"""
import os
import shutil
import pyarrow.parquet as pq
from pyiceberg.catalog.sql import SqlCatalog
from pyiceberg.types import StringType

# A local "warehouse" + catalog. On AWS, the Glue Data Catalog plays the catalog
# role and S3 is the warehouse. (Outputs land under git-ignored foundations/data/.)
WH = os.path.abspath("foundations/data/_iceberg_wh")
shutil.rmtree(WH, ignore_errors=True)
os.makedirs(WH)

catalog = SqlCatalog("local", uri=f"sqlite:///{WH}/catalog.db", warehouse=f"file://{WH}")
catalog.create_namespace("taxi")

data = pq.read_table(
    "foundations/data/yellow_tripdata_2024-01.parquet",
    columns=["tpep_pickup_datetime", "fare_amount", "trip_distance"],
).slice(0, 50_000)

# 1) CREATE an Iceberg table from an Arrow schema.
trips = catalog.create_table("taxi.trips", schema=data.schema)

# 2) APPEND -> snapshot #1. Appends are atomic: readers never see a half-write.
trips.append(data)
print(f"append #1: {trips.scan().to_arrow().num_rows} rows, {len(trips.snapshots())} snapshot")

# 3) APPEND more -> snapshot #2. Iceberg keeps every version.
trips.append(data.slice(0, 1_000))
print(f"append #2: {trips.scan().to_arrow().num_rows} rows, {len(trips.snapshots())} snapshots")

# 4) TIME TRAVEL: read the table AS OF the first snapshot (before append #2).
first_snapshot = trips.snapshots()[0].snapshot_id
as_of = trips.scan(snapshot_id=first_snapshot).to_arrow().num_rows
print(f"time-travel to snapshot #1: {as_of} rows (the pre-append-#2 state)")

# 5) SCHEMA EVOLUTION: add a column safely — old data isn't rewritten.
with trips.update_schema() as upd:
    upd.add_column("source", StringType())
print("columns after add_column:", trips.schema().column_names)

print(
    """
Iceberg turns a pile of Parquet files into a real TABLE on the lake, adding:
  ACID transactions, snapshots, time travel, safe schema evolution, hidden
  partitioning, and (on AWS) row-level MERGE/UPSERT. We rely on MERGE for
  incremental loads (P17) and slowly-changing dimensions (P27). Athena, Glue,
  EMR, and Redshift Spectrum can all read Iceberg.
"""
)
