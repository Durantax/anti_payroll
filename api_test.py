
import requests
import json
from datetime import datetime

BASE_URL = "http://127.0.0.1:8000"

def test_health():
    print(f"Testing /health...")
    try:
        resp = requests.get(f"{BASE_URL}/health")
        print(f"Status: {resp.status_code}, Body: {resp.text}")
    except Exception as e:
        print(f"Health check failed: {e}")

def test_employee_crud():
    print(f"\nTesting /employees/upsert (Create)...")
    new_emp = {
        "clientId": 1,
        "name": "__TEST_EMP__",
        "birthDate": "990101",
        "employmentType": "regular",
        "salaryType": "MONTHLY",
        "baseSalary": 3000000,
        "useEmail": False
    }
    try:
        resp = requests.post(f"{BASE_URL}/employees/upsert", json=new_emp)
        print(f"Create Status: {resp.status_code}")
        data = resp.json()
        emp_id = data.get("id")
        print(f"Created ID: {emp_id}")
        
        if emp_id:
            print(f"Testing /employees/upsert (Update)...")
            new_emp['id'] = emp_id
            new_emp['name'] = "__TEST_EMP_UPDATED__"
            resp = requests.post(f"{BASE_URL}/employees/upsert", json=new_emp)
            print(f"Update Status: {resp.status_code}")
            
            print(f"Testing /employees/{{id}} (Delete)...")
            resp = requests.delete(f"{BASE_URL}/employees/{emp_id}")
            print(f"Delete Status: {resp.status_code}")
            
    except Exception as e:
        print(f"Employee CRUD failed: {e}")

def test_payroll_result_save():
    print(f"\nTesting /payroll/results/save...")
    # Assume EmployeeId 1 exists for test, or fail gracefully
    payload = {
        "employeeId": 1, 
        "clientId": 1,
        "year": 2029, # Future year to avoid conflict
        "month": 12,
        "baseSalary": 2500000,
        "overtimeAllowance": 100000,
        "nightAllowance": 0,
        "holidayAllowance": 0,
        "weeklyHolidayPay": 0,
        "bonus": 500000,
        "totalPayment": 3100000,
        "nationalPension": 0,
        "healthInsurance": 0,
        "longTermCare": 0,
        "employmentInsurance": 0,
        "incomeTax": 0,
        "localIncomeTax": 0,
        "totalDeduction": 0,
        "netPay": 3100000,
        "calculatedBy": "test_script"
    }
    try:
        resp = requests.post(f"{BASE_URL}/payroll/results/save", json=payload)
        print(f"Save Status: {resp.status_code}, Body: {resp.text}")
    except Exception as e:
        print(f"Payroll Save failed: {e}")

if __name__ == "__main__":
    test_health()
    test_employee_crud()
    test_payroll_result_save()
