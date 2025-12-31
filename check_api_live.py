import requests
import sys

BASE_URL = "http://127.0.0.1:8000"

def check(url):
    print(f"Checking {url} ...")
    try:
        r = requests.get(url, headers={"X-API-Key": ""}, timeout=5)
        print(f"Status: {r.status_code}")
        if r.status_code == 200:
            try:
                data = r.json()
                if isinstance(data, list):
                    print(f"Count: {len(data)}")
                    if data:
                        print(f"Sample: {data[0]}")
                else:
                    print(f"Data: {data}")
                return data
            except:
                print(f"Response text: {r.text}")
        else:
            print(f"Error: {r.text}")
    except Exception as e:
        print(f"Exception: {e}")

print("=== LIVE SERVER CHECK ===")
# 1. App Settings
check(f"{BASE_URL}/app/settings")
# 2. SMTP Config
check(f"{BASE_URL}/smtp/config")
# 3. Clients
clients = check(f"{BASE_URL}/clients")

if clients and len(clients) > 0:
    cid = clients[0]['id']
    print(f"\nChecking Employees for Client {cid}")
    employees = check(f"{BASE_URL}/clients/{cid}/employees")
    if not employees:
        print("[WARN] Employees list empty.")
    else:
        print(f"Found {len(employees)} employees.")
else:
    print("[WARN] No clients found.")
