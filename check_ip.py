import requests
import sys

URL_IP = "http://25.2.89.129:8000/health"
URL_LOCAL = "http://127.0.0.1:8000/health"

def test(url, name):
    print(f"Testing {name} ({url})...")
    try:
        r = requests.get(url, timeout=2)
        print(f"[{name}] Status: {r.status_code}")
        if r.status_code == 200:
            print(f"[{name}] SUCCESS. Response: {r.text}")
        else:
            print(f"[{name}] Failed with status {r.status_code}")
    except Exception as e:
        print(f"[{name}] CONNECTION FAILED: {e}")

print("=== CONNECTIVITY CHECK ===")
test(URL_LOCAL, "Localhost")
test(URL_IP, "Configured IP")
