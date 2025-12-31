#!/usr/bin/env python3
"""
ODBC 드라이버 자동 감지 및 수정
server.py와 init_db.py의 드라이버 설정을 자동으로 수정합니다
"""
import pyodbc
import os

print("=" * 60)
print("ODBC 드라이버 자동 감지")
print("=" * 60)

# 1. 설치된 드라이버 확인
drivers = pyodbc.drivers()
sql_drivers = [d for d in drivers if "SQL Server" in d]

if not sql_drivers:
    print("❌ SQL Server ODBC 드라이버가 설치되어 있지 않습니다!")
    print("\n해결 방법:")
    print("1. https://go.microsoft.com/fwlink/?linkid=2249004")
    print("   (ODBC Driver 18 다운로드)")
    print("2. 다운로드 후 설치")
    print("3. 이 스크립트 다시 실행")
    exit(1)

print(f"\n✅ SQL Server 드라이버 {len(sql_drivers)}개 발견:")
for driver in sql_drivers:
    print(f"   - {driver}")

# 2. 최적의 드라이버 선택
recommended = None
if "ODBC Driver 18 for SQL Server" in drivers:
    recommended = "ODBC Driver 18 for SQL Server"
elif "ODBC Driver 17 for SQL Server" in drivers:
    recommended = "ODBC Driver 17 for SQL Server"
elif "ODBC Driver 13 for SQL Server" in drivers:
    recommended = "ODBC Driver 13 for SQL Server"
elif "SQL Server Native Client 11.0" in drivers:
    recommended = "SQL Server Native Client 11.0"
else:
    recommended = sql_drivers[0]

print(f"\n✅ 선택된 드라이버: {recommended}")

# 3. server.py 수정
print(f"\n📝 server.py 수정 중...")
with open("server.py", "r", encoding="utf-8") as f:
    content = f.read()

old_line = '    "DRIVER={ODBC Driver 18 for SQL Server};"'
new_line = f'    "DRIVER={{{recommended}}}"'

if old_line in content:
    content = content.replace(old_line, new_line)
    with open("server.py", "w", encoding="utf-8") as f:
        f.write(content)
    print(f"   ✅ server.py 수정 완료")
else:
    print(f"   ℹ️  server.py 이미 최신 상태")

# 4. init_db.py 수정
print(f"\n📝 init_db.py 수정 중...")
with open("init_db.py", "r", encoding="utf-8") as f:
    content = f.read()

old_line = '    "DRIVER={ODBC Driver 18 for SQL Server};"'
new_line = f'    "DRIVER={{{recommended}}}"'

if old_line in content:
    content = content.replace(old_line, new_line)
    with open("init_db.py", "w", encoding="utf-8") as f:
        f.write(content)
    print(f"   ✅ init_db.py 수정 완료")
else:
    print(f"   ℹ️  init_db.py 이미 최신 상태")

print("\n" + "=" * 60)
print("✅ 완료! 이제 다시 실행하세요:")
print("=" * 60)
print("python init_db.py")
print("python server.py")
print("=" * 60)
