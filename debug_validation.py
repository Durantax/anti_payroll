from server import get_employees, EmployeeOut
from pydantic import ValidationError

print("Fetching raw data...")
employees = get_employees(17) # Wait, my check_client_specific found '국민테크' as ID 5??
# Let me re-check check_client_specific output from Step 142/158.
# Output: Found Client: (주)국민테크 (ID: 5)
# So I should check ID 5.

client_id = 5
full_data = get_employees(client_id)
print(f"Fetched {len(full_data)} rows for Client {client_id}")

fail_count = 0
for i, row in enumerate(full_data):
    try:
        # Convert dict to model
        EmployeeOut(**row)
    except ValidationError as e:
        print(f"Row {i} Failed Validation: {e}")
        print(f"Row Data: {row}")
        fail_count += 1

if fail_count == 0:
    print("All rows validated successfully against EmployeeOut.")
else:
    print(f"{fail_count} rows failed validation.")
