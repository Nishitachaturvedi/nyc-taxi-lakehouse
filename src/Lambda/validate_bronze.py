import urllib.parse

def validate_object(key:str,size:int) -> list :
    problem = []

    if not key.startswith("bronze/"):
        problem.append("not under bronze/ prefix")

    if not key.endswith((".parquet",".csv")):
        problem.append("unexpected file type (want .parquet/.csv)")

    if size == 0 :
        problem.append("empty object (0 bytes)")

    return problem


def handler(event, context=None) :
    results = []

    for record in event.get("Records",[]):
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        size = record["s3"]["object"].get("size",0)
        bucket = record["s3"]["bucket"]["name"]
        problems = validate_object(key,size)

        if problems :
            print(f"REJECT s3://{bucket}/{key} -> {problems}")
            results.append({"key": key, "ok": False, "problems": problems})
        else :
            print(f"OK     s3://{bucket}/{key} ({size} bytes)")
            results.append({"key" : key, "ok": True} )

    return {"checked":len(results), "results": results} 


if __name__ == "__main__" :
    assert validate_object("bronze/yellow_tripdata/year=2024/month=01/f.parquet", 1234) == []
    assert "not under bronze/ prefix" in validate_object("silver/f.parquet", 10)
    assert "empty object (0 bytes)" in validate_object("bronze/f.parquet", 0)
    assert "unexpected file type (want .parquet/.csv)" in validate_object("bronze/f.txt", 10)

    sample_event = {
        "Records": [
            {"s3": {"bucket": {"name": "lake"}, "object": {"key": "bronze/a.parquet", "size": 100}}},
            {"s3": {"bucket": {"name": "lake"}, "object": {"key": "bronze/bad.txt", "size": 0}}},
        ]
}
    out = handler(sample_event)
    assert out["checked"] == 2 and out["results"][0]["ok"] and not out["results"][1]["ok"]
    print("validate_bronze: all local tests passed ✓")



    



    