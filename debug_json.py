from server import get_employees
from fastapi.encoders import jsonable_encoder
import json

print("Fetching data for Client 5...")
data = get_employees(5)
print(f"Rows: {len(data)}")

print("Attempting JSON serialization...")
try:
    encoded = jsonable_encoder(data)
    json_str = json.dumps(encoded)
    print("Success: Data is JSON serializable.")
    print(f"Sample JSON: {json_str[:200]}")
except Exception as e:
    print(f"JSON Serialization Failed: {e}")
    # Inspect rows
    for i, r in enumerate(data):
        try:
            json.dumps(jsonable_encoder(r))
        except:
            print(f"Row {i} causes error: {r}")
