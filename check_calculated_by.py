import pyodbc
import os

DB_SERVER = os.getenv("DB_SERVER", "25.2.89.129")
DB_PORT = os.getenv("DB_PORT", "1433")
DB_NAME = os.getenv("DB_NAME", "기본정보")
DB_USER = os.getenv("DB_USER", "playtest")
DB_PASSWORD = os.getenv("DB_PASSWORD", "Playtest123!")

conn_str = f"DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={DB_SERVER},{DB_PORT};DATABASE={DB_NAME};UID={DB_USER};PWD={DB_PASSWORD};TrustServerCertificate=yes;"

try:
    conn = pyodbc.connect(conn_str, timeout=5)
    cur = conn.cursor()
    
    # Check if CalculatedBy column exists
    cur.execute("""
        SELECT COUNT(*) 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'PayrollResults' 
        AND COLUMN_NAME = 'CalculatedBy'
    """)
    
    exists = cur.fetchone()[0]
    
    if exists:
        print("✅ CalculatedBy 컬럼이 이미 존재합니다.")
        
        # Check sample data
        cur.execute("SELECT TOP 5 EmployeeId, Year, Month, CalculatedBy FROM dbo.PayrollResults ORDER BY Year DESC, Month DESC")
        rows = cur.fetchall()
        print("\n샘플 데이터:")
        for row in rows:
            print(f"  EmployeeId={row[0]}, Year={row[1]}, Month={row[2]}, CalculatedBy={row[3]}")
    else:
        print("❌ CalculatedBy 컬럼이 없습니다. 마이그레이션이 필요합니다.")
    
    conn.close()
except Exception as e:
    print(f"에러: {e}")
