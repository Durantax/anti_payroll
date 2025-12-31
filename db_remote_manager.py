import os
import re
import pyodbc
from typing import List

# =========================
# 환경변수 (server.py와 동일하게 설정)
# =========================
DB_SERVER = os.getenv("DB_SERVER", "25.2.89.129")
DB_PORT = os.getenv("DB_PORT", "1433")
DB_NAME = os.getenv("DB_NAME", "기본정보")
DB_USER = os.getenv("DB_USER", "user1")
DB_PASSWORD = os.getenv("DB_PASSWORD", "1536")
ODBC_DRIVER = os.getenv("ODBC_DRIVER", "ODBC Driver 18 for SQL Server")

DRIVERS_TO_TRY = [
    os.getenv("ODBC_DRIVER", "ODBC Driver 18 for SQL Server"),
    "ODBC Driver 17 for SQL Server",
    "ODBC Driver 13 for SQL Server",
    "SQL Server Native Client 11.0",
    "SQL Server",
]

def get_conn() -> pyodbc.Connection:
    last_error = None
    for driver in DRIVERS_TO_TRY:
        conn_str = (
            f"DRIVER={{{driver}}};"
            f"SERVER={DB_SERVER},{DB_PORT};"
            f"DATABASE={DB_NAME};"
            f"UID={DB_USER};PWD={DB_PASSWORD};"
            "TrustServerCertificate=YES;"
            "Encrypt=YES;"
            "Connection Timeout=30;"
        )
        if driver == "SQL Server":
            # Old driver might not support Encrypt=YES
            conn_str = conn_str.replace("Encrypt=YES;", "")
        
        try:
            print(f"Trying driver: {driver} ...")
            conn = pyodbc.connect(conn_str)
            print(f"Success with driver: {driver}")
            return conn
        except Exception as e:
            last_error = e
            print(f"Failed with driver {driver}: {e}")
    
    raise last_error

def parse_batches_from_file(filepath: str) -> List[str]:
    """
    Reads a SQL file and splits it into batches by 'GO' keyword.
    """
    if not os.path.exists(filepath):
        print(f"[ERROR] File not found: {filepath}")
        return []

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split by 'GO' (case insensitive, on its own line)
    # Using regex to match GO on a separate line
    batches = re.split(r'(?i)^\s*GO\s*$', content, flags=re.MULTILINE)
    
    # Filter out empty batches
    return [b.strip() for b in batches if b.strip()]

def apply_sql_safely(filepath: str):
    print(f"Applying SQL from {filepath}...")
    conn = None
    try:
        conn = get_conn()
        cursor = conn.cursor()
        
        batches = parse_batches_from_file(filepath)
        print(f"Found {len(batches)} batches.")

        success_count = 0
        skip_count = 0
        error_count = 0

        for i, batch in enumerate(batches):
            # Check if batch contains risky commands
            risky_keywords = ["DROP TABLE", "DELETE FROM", "TRUNCATE TABLE"]
            is_risky = any(k in batch.upper() for k in risky_keywords)
            
            if is_risky:
                print(f"[WARN] Skipping Batch #{i+1} due to risky keywords: {batch[:50]}...")
                skip_count += 1
                continue

            try:
                cursor.execute(batch)
                conn.commit()
                print(f"[OK] Batch #{i+1} executed.")
                success_count += 1
            except Exception as e:
                # If "There is already an object named..." error, we can consider it "Skipped" or "OK" depending on context.
                # But here we just log error. Ideally our script uses "IF OBJECT_ID... IS NULL" checks.
                err_msg = str(e)
                if "There is already an object named" in err_msg or "Column names in each table must be unique" in err_msg:
                    print(f"[SKIP] Batch #{i+1} already exists/applied: {err_msg.split(']')[0]}...")
                    skip_count += 1
                else:
                    print(f"[ERR] Batch #{i+1} failed: {e}")
                    error_count += 1

        print("="*30)
        print(f"Summary: Success={success_count}, Skipped={skip_count}, Errors={error_count}")
        print("="*30)

    except pyodbc.Error as ex:
        print(f"[FATAL] DB Connection failed: {ex}")
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    # We will invoke this specifically for script_additions.sql first to be safe, 
    # or script.sql if we are confident "IF NOT EXISTS" logic handles it.
    # Since we appended to script.sql, we can try running script_additions.sql first locally to verify.
    # But rule says "script.sql" is the source.
    # Our script.sql is huge and mostly legacy.
    # Let's run `script_additions.sql` solely for now to be fast and safe.
    
    target_file = "script_additions.sql"
    if os.path.exists(target_file):
        apply_sql_safely(target_file)
    else:
        print(f"Target file {target_file} not found.")
