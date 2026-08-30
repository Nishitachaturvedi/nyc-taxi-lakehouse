"""
P3 — File-format & compression benchmark on real taxi data, with an Athena
cost estimate. Proves WHY the lake stores Parquet (bytes scanned = money).

Run from the repo root:  python3 src/format_bench/compare_formats.py
Requires: pandas, pyarrow.  Source: foundations/data/yellow_tripdata_2024-01.parquet
Outputs go under foundations/data/ (git-ignored).
"""
import os
import pandas as pd

SRC = "foundations/data/yellow_tripdata_2024-01.parquet"
OUT = "foundations/data/_fmt_bench"
ATHENA_USD_PER_TB = 5.0          # Athena charges ~$5 per TB scanned
os.makedirs(OUT, exist_ok=True)

# Use a 500k-row sample so the CSV/JSON writes are quick.
df = pd.read_parquet(SRC).head(500_000)


def mb(path):
    return os.path.getsize(path) / 1_000_000


rows = []
p = f"{OUT}/data.csv";        df.to_csv(p, index=False);                       rows.append(("CSV (uncompressed)", mb(p)))
p = f"{OUT}/data.csv.gz";     df.to_csv(p, index=False, compression="gzip");   rows.append(("CSV + gzip", mb(p)))
p = f"{OUT}/data.jsonl";      df.to_json(p, orient="records", lines=True);     rows.append(("JSON (lines)", mb(p)))
for codec in ["snappy", "zstd", "gzip"]:
    p = f"{OUT}/data_{codec}.parquet"
    df.to_parquet(p, compression=codec)
    rows.append((f"Parquet + {codec}", mb(p)))

# A "full table scan" reads the whole file. Athena cost = bytes/TB * $5.
print(f"{'format':22} {'size (MB)':>10} {'full-scan cost ($)':>20}")
print("-" * 54)
for name, size in rows:
    cost = (size / 1_000_000) * ATHENA_USD_PER_TB   # MB -> TB (/1e6) -> $
    print(f"{name:22} {size:10.2f} {cost:20.6f}")

csv_mb = rows[0][1]
pq_mb = next(s for n, s in rows if n == "Parquet + snappy")
print(f"\nParquet+snappy is ~{csv_mb / pq_mb:.1f}x smaller than CSV "
      f"=> ~{csv_mb / pq_mb:.1f}x cheaper to full-scan in Athena.")

# Column pruning: Athena (and Parquet) reads only the columns you SELECT.
full = pd.read_parquet(f"{OUT}/data_snappy.parquet")
print(f"\nColumn pruning: SELECTing 2 of {full.shape[1]} columns scans only "
      f"~{2 / full.shape[1] * 100:.0f}% of the bytes (vs SELECT *).")
print("\nLesson: Parquet + compression + selecting few columns = a fraction of the scan cost.")
