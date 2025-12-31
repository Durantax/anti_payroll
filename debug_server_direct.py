from server import get_clients, get_app_settings, get_smtp_config, get_employees, get_conn, table_exists
from fastapi import HTTPException
import sys

# Mock header/dependency if needed? No, functions don't take them as args usually.
# require_api_key is a dependency, but get_clients() signature is `def get_clients():` so we can just call it.

def run_test(name, func, *args):
    print(f"\n--- Testing {name} ---")
    try:
        result = func(*args)
        if isinstance(result, list):
            print(f"Success. Count: {len(result)}")
            if len(result) > 0:
                print(f"Sample: {result[0]}")
        else:
            print(f"Success: {result}")
        return result
    except HTTPException as he:
        print(f"HTTP Error {he.status_code}: {he.detail}")
    except Exception as e:
        print(f"CRITICAL ERROR: {e}")
        import traceback
        traceback.print_exc()

def check_tables():
    print("\n--- Checking Critical Tables ---")
    conn = get_conn()
    tables = ["dbo.거래처", "dbo.Employees", "dbo.AppSettings", "dbo.SmtpConfig"]
    for t in tables:
        exists = table_exists(conn, t)
        print(f"{t}: {'EXISTS' if exists else 'MISSING'}")
    conn.close()

if __name__ == "__main__":
    check_tables()
    
    # 1. App Settings
    run_test("App Settings", get_app_settings)

    # 2. SMTP Config
    run_test("SMTP Config", get_smtp_config)

    # 3. Clients
    clients = run_test("Clients", get_clients)

    # 4. Employees (if clients exist)
    if clients and len(clients) > 0:
        cid = None
        # Try to find a client ID. Clients return ClientOut (Pydantic model) or dict?
        # server.py returns `rows` which are dicts or Pydantic models.
        # `fetch_all` returns dicts.
        # `get_clients` returns `rows` (List[Dict]).
        first_client = clients[0]
        if isinstance(first_client, dict):
            cid = first_client.get("id")
        else:
            cid = first_client.id
            
        print(f"Using Client ID: {cid}")
        run_test(f"Employees (Client {cid})", get_employees, cid)
    else:
        print("\n[WARN] No clients found, skipping employee test.")
