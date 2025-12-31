import requests
import json
import sys

# URL = "http://25.2.89.129:8000"
URL = "http://127.0.0.1:8000"

def debug_save():
    print("Testing /payroll/results/save ...")
    payload = {
        'employeeId': 14, # From check_client_specific.py (TEST_RAW)
        'clientId': 5, # (주)국민테크
        'year': 2024,
        'month': 12,
        'baseSalary': 3000000,
        'overtimeAllowance': 0,
        'nightAllowance': 0,
        'holidayAllowance': 0,
        'weeklyHolidayPay': 0,
        'bonus': 0,
        'totalPayment': 3000000,
        'nationalPension': 135000,
        'healthInsurance': 100000,
        'longTermCare': 10000,
        'employmentInsurance': 20000,
        'incomeTax': 50000,
        'localIncomeTax': 5000,
        'totalDeduction': 320000,
        'netPay': 2680000,
        'normalHours': 209,
        'overtimeHours': 0,
        'nightHours': 0,
        'holidayHours': 0,
        'attendanceWeeks': 4,
        'calculatedBy': 'debug_script'
    }

    try:
        r = requests.post(f"{URL}/payroll/results/save", json=payload)
        print(f"Status: {r.status_code}")
        if r.status_code != 200:
            print("Response Body:")
            print(r.text)
        else:
            print("SUCCESS")
    except Exception as e:
        print(f"Request Failed: {e}")

if __name__ == "__main__":
    debug_save()
