"""
P4 — Partitioning & the small-files problem, demonstrated locally.

Shows: (1) a GOOD partition key (date, low cardinality) -> few sensible files;
       (2) a BAD partition key (location id, high cardinality) -> tiny-file explosion;
       (3) compaction -> combine many small files into one.

Run from the repo root:  python3 src/format_bench/partition_demo.py
Requires: pandas, pyarrow.  Outputs under foundations/data/ (git-ignored).
"""
import os
import glob
import shutil
import pandas as pd

SRC = "foundations/data/yellow_tripdata_2024-01.parquet"
OUT = "foundations/data/_part_demo"
shutil.rmtree(OUT, ignore_errors=True)
os.makedirs(OUT, exist_ok=True)

df = pd.read_parquet(
    SRC, columns=["tpep_pickup_datetime", "PULocationID", "fare_amount", "trip_distance"]
).head(500_000)
df["pickup_date"] = pd.to_datetime(df["tpep_pickup_datetime"]).dt.date.astype(str)


def files_and_mb(path):
    fs = glob.glob(f"{path}/**/*.parquet", recursive=True)
    return len(fs), sum(os.path.getsize(f) for f in fs) / 1_000_000


# (1) GOOD: partition by date — low cardinality (~31 values) -> ~31 files.
good = f"{OUT}/by_date"
df.to_parquet(good, partition_cols=["pickup_date"])
n, sz = files_and_mb(good)
print(f"partition by DATE             : {n:4d} files, {sz:6.1f} MB   (good: few, reasonably sized)")

# (2) BAD: partition by location id — high cardinality (~260 values) -> many tiny files.
bad = f"{OUT}/by_location"
df.to_parquet(bad, partition_cols=["PULocationID"])
n, sz = files_and_mb(bad)
print(f"partition by PULocationID     : {n:4d} files, {sz:6.1f} MB   (BAD: small-files explosion)")

# (3) COMPACTION: rewrite into a single file (engines/Iceberg do this automatically).
comp = f"{OUT}/compacted.parquet"
df.drop(columns=["pickup_date"]).to_parquet(comp, compression="snappy")
print(f"compacted to ONE file         :    1 files, {os.path.getsize(comp)/1_000_000:6.1f} MB   (fix)")

print("""
Why it matters:
  * Partition on columns you FILTER by often, with LOW-to-MEDIUM cardinality
    (date works great; a per-trip id is terrible).
  * Too many tiny files = slow queries + high request costs + metadata overhead.
  * Target ~128 MB-1 GB files. 'Compaction' merges small files back into big ones.
""")