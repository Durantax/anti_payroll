
import re

def count_items():
    with open("server.py", "r", encoding="utf-8") as f:
        lines = f.readlines()

    # update_sets
    start = 1328
    end = 1360
    cnt_update_sets = 0
    for i in range(start, end):
        if "?" in lines[i]:
            cnt_update_sets += 1
    print(f"Update Sets ? count (static): {cnt_update_sets}")

    # insert_cols
    start = 1363
    end = 1377
    cnt_insert_cols = 0
    text = "".join(lines[start:end])
    # split by comma
    matches = re.findall(r'"[^"]+"', text)
    cnt_insert_cols = len(matches)
    print(f"Insert Cols count: {cnt_insert_cols}")

    # insert_vals
    # It is a line: insert_vals = ["?"] * 34
    for line in lines:
        if "insert_vals =" in line and "*" in line:
            print(f"Insert Vals Line: {line.strip()}")

    # params_update
    start = 1381
    end = 1413
    cnt_params_update = 0
    # specific logic to count items in list definition?
    # Rough count by commas?
    text = "".join(lines[start:end])
    # remove comments
    # count commas + 1 (last item might not have comma if enclosed in [])
    # easier: just use python AST or simple line counting if 1 item per line
    # Server.py has 1 item per line mostly.
    cnt_params_update = end - start
    print(f"Params Update Lines (approx): {cnt_params_update}")

    # params_insert
    start = 1415
    end = 1447
    text = "".join(lines[start:end])
    # Line 1416: data["employeeId"], data["clientId"], data["year"], data["month"],
    # This line has 4 items.
    # Other lines have 1 item.
    cnt_params_insert = 0
    for line in lines[start:end]:
        if "employeeId" in line and "year" in line:
            cnt_params_insert += 4
        else:
            cnt_params_insert += 1
    print(f"Params Insert Count (approx): {cnt_params_insert}")

if __name__ == "__main__":
    count_items()
