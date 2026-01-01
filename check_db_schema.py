import pyodbc

# server.py와 동일한 DB 연결 설정
DB_SERVER = "25.2.89.129"
DB_PORT = "1433"
DB_NAME = "기본정보"
DB_USER = "user1"
DB_PASSWORD = "1536"

conn_str = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={DB_SERVER},{DB_PORT};"
    f"DATABASE={DB_NAME};"
    f"UID={DB_USER};PWD={DB_PASSWORD};"
    "TrustServerCertificate=YES;"
    "Encrypt=YES;"
    "Connection Timeout=5;"
)

try:
    conn = pyodbc.connect(conn_str)
    print(f"연결 성공: {DB_SERVER}\n")
except Exception as e:
    print(f"DB 연결 실패: {e}")
    exit(1)
cursor = conn.cursor()

print("=" * 80)
print("1. Allowance/Deduction 관련 테이블 목록")
print("=" * 80)
cursor.execute("""
    SELECT TABLE_NAME 
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_NAME LIKE '%Allowance%' OR TABLE_NAME LIKE '%Deduction%'
    ORDER BY TABLE_NAME
""")
for row in cursor.fetchall():
    print(f"  - {row[0]}")

print("\n" + "=" * 80)
print("2. AllowanceMaster 테이블 구조 (있다면)")
print("=" * 80)
cursor.execute("""
    SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'AllowanceMaster'
    ORDER BY ORDINAL_POSITION
""")
rows = cursor.fetchall()
if rows:
    for row in rows:
        print(f"  {row[0]:<30} {row[1]:<15} NULL:{row[2]:<3} DEFAULT:{row[3]}")
else:
    print("  테이블 없음")

print("\n" + "=" * 80)
print("3. AllowanceMasters 테이블 구조 (있다면)")
print("=" * 80)
cursor.execute("""
    SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'AllowanceMasters'
    ORDER BY ORDINAL_POSITION
""")
rows = cursor.fetchall()
if rows:
    for row in rows:
        print(f"  {row[0]:<30} {row[1]:<15} NULL:{row[2]:<3} DEFAULT:{row[3]}")
else:
    print("  테이블 없음")

print("\n" + "=" * 80)
print("4. DeductionMaster 테이블 구조 (있다면)")
print("=" * 80)
cursor.execute("""
    SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'DeductionMaster'
    ORDER BY ORDINAL_POSITION
""")
rows = cursor.fetchall()
if rows:
    for row in rows:
        print(f"  {row[0]:<30} {row[1]:<15} NULL:{row[2]:<3} DEFAULT:{row[3]}")
else:
    print("  테이블 없음")

print("\n" + "=" * 80)
print("5. DeductionMasters 테이블 구조 (있다면)")
print("=" * 80)
cursor.execute("""
    SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'DeductionMasters'
    ORDER BY ORDINAL_POSITION
""")
rows = cursor.fetchall()
if rows:
    for row in rows:
        print(f"  {row[0]:<30} {row[1]:<15} NULL:{row[2]:<3} DEFAULT:{row[3]}")
else:
    print("  테이블 없음")

print("\n" + "=" * 80)
print("6. PayrollMonthlyInput의 Additional 관련 컬럼")
print("=" * 80)
cursor.execute("""
    SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'PayrollMonthlyInput' 
    AND (COLUMN_NAME LIKE '%Additional%' OR COLUMN_NAME LIKE '%Extra%')
    ORDER BY ORDINAL_POSITION
""")
rows = cursor.fetchall()
if rows:
    for row in rows:
        print(f"  {row[0]:<30} {row[1]:<15} NULL:{row[2]:<3} DEFAULT:{row[3]}")
else:
    print("  컬럼 없음")

print("\n" + "=" * 80)
print("7. PayrollMonthlyInput의 모든 컬럼 목록")
print("=" * 80)
cursor.execute("""
    SELECT COLUMN_NAME, DATA_TYPE
    FROM INFORMATION_SCHEMA.COLUMNS 
    WHERE TABLE_NAME = 'PayrollMonthlyInput'
    ORDER BY ORDINAL_POSITION
""")
for row in cursor.fetchall():
    print(f"  {row[0]:<35} {row[1]}")

conn.close()
print("\n완료!")
