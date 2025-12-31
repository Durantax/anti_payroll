#!/usr/bin/env python3
"""
ODBC 드라이버 확인 스크립트
"""
import pyodbc

print("=" * 60)
print("설치된 ODBC 드라이버 목록")
print("=" * 60)

drivers = pyodbc.drivers()
if not drivers:
    print("⚠️  설치된 ODBC 드라이버가 없습니다!")
    print("\n해결 방법:")
    print("1. https://go.microsoft.com/fwlink/?linkid=2249004")
    print("   (ODBC Driver 18 다운로드)")
    print("2. 다운로드 후 설치")
    print("3. 이 스크립트 다시 실행")
else:
    print(f"총 {len(drivers)}개 드라이버 발견:\n")
    for i, driver in enumerate(drivers, 1):
        marker = "✅" if "SQL Server" in driver else "  "
        print(f"{marker} [{i}] {driver}")
    
    print("\n" + "=" * 60)
    
    # SQL Server 드라이버 찾기
    sql_drivers = [d for d in drivers if "SQL Server" in d]
    if sql_drivers:
        print(f"✅ SQL Server 드라이버 {len(sql_drivers)}개 발견:")
        for driver in sql_drivers:
            print(f"   - {driver}")
        
        # 권장 드라이버
        recommended = None
        if "ODBC Driver 18 for SQL Server" in drivers:
            recommended = "ODBC Driver 18 for SQL Server"
        elif "ODBC Driver 17 for SQL Server" in drivers:
            recommended = "ODBC Driver 17 for SQL Server"
        elif "SQL Server Native Client 11.0" in drivers:
            recommended = "SQL Server Native Client 11.0"
        elif sql_drivers:
            recommended = sql_drivers[0]
        
        if recommended:
            print(f"\n✅ 권장 드라이버: {recommended}")
            print(f"\n📝 server.py와 init_db.py에서 사용할 드라이버:")
            print(f'   DRIVER={{{recommended}}}')
    else:
        print("❌ SQL Server 드라이버가 없습니다!")
        print("\n해결 방법:")
        print("https://go.microsoft.com/fwlink/?linkid=2249004")
        print("(ODBC Driver 18 for SQL Server 다운로드)")

print("=" * 60)
