import requests
import sys

BASE_URL = "http://127.0.0.1:8000"

def get_employees_for_client(name_part):
    print(f"Finding client matching '{name_part}'...")
    r = requests.get(f"{BASE_URL}/clients", headers={"X-API-Key": ""})
    if r.status_code != 200:
        print(f"Error getting clients: {r.status_code}")
        return

    clients = r.json()
    target_id = None
    for c in clients:
        if name_part in c['name']:
            print(f"Found Client: {c['name']} (ID: {c['id']})")
            target_id = c['id']
            break
            
    if target_id:
        print(f"Fetching employees for Client ID {target_id}...")
        r = requests.get(f"{BASE_URL}/clients/{target_id}/employees", headers={"X-API-Key": ""})
        if r.status_code == 200:
            emps = r.json()
            print(f"Employees Found: {len(emps)}")
            for e in emps:
                print(f"- {e['name']} (ID: {e['employeeId']})")
        else:
            print(f"Error fetching employees: {r.status_code}")
            print(f"Response Body: {r.text}")
    else:
        print(f"Client '{name_part}' not found.")

get_employees_for_client("국민테크")
