from fastapi.testclient import TestClient
from server import app, get_conn
import pyodbc

client = TestClient(app)

def test_endpoint(name, url):
    print(f"\n--- Testing {name} ({url}) ---")
    try:
        response = client.get(url, headers={"X-API-Key": ""})
        print(f"Status: {response.status_code}")
        if response.status_code != 200:
            print(f"Error: {response.text}")
        else:
            data = response.json()
            if isinstance(data, list):
                print(f"Success. Count: {len(data)}")
                if len(data) > 0:
                    print(f"Sample: {data[0]}")
            else:
                print(f"Success. Data: {data}")
    except Exception as e:
        print(f"CRITICAL EXCEPTION: {e}")

# 1. Test Settings (User reported 500)
test_endpoint("App Settings", "/app/settings")

# 2. Test SMTP (User reported 500)
test_endpoint("SMTP Config", "/smtp/config")

# 3. Test Clients (User says employees not showing, maybe clients too?)
test_endpoint("Clients", "/clients")

# 4. Test Employees (User says not showing)
# We need a client ID first.
try:
    r = client.get("/clients", headers={"X-API-Key": ""})
    if r.status_code == 200 and len(r.json()) > 0:
        client_id = r.json()[0]['id']
        test_endpoint(f"Employees (Client {client_id})", f"/clients/{client_id}/employees")
    else:
        print("\n[WARN] Cannot test employees because no clients were found or client endpoint failed.")
except:
    pass
