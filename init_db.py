#!/usr/bin/env python3
"""
DB 초기화 스크립트
AppSettings와 SmtpConfig 테이블에 기본 데이터 삽입
"""
import os
import pyodbc

DB_SERVER = os.getenv("DB_SERVER", "25.2.89.129")
DB_PORT = os.getenv("DB_PORT", "1433")
DB_NAME = os.getenv("DB_NAME", "기본정보")
DB_USER = os.getenv("DB_USER", "user1")
DB_PASSWORD = os.getenv("DB_PASSWORD", "1536")

CONN_STR = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={DB_SERVER},{DB_PORT};"
    f"DATABASE={DB_NAME};"
    f"UID={DB_USER};PWD={DB_PASSWORD};"
    "TrustServerCertificate=YES;"
    "Encrypt=YES;"
    "Connection Timeout=5;"
)

def init_db():
    """DB 초기 데이터 삽입"""
    print("=" * 60)
    print("DB 초기화 시작")
    print("=" * 60)
    
    try:
        conn = pyodbc.connect(CONN_STR)
        cursor = conn.cursor()
        
        # AppSettings 체크 및 삽입
        print("\n[1] AppSettings 테이블 확인...")
        cursor.execute("SELECT COUNT(*) FROM dbo.AppSettings WHERE Id = 1")
        count = cursor.fetchone()[0]
        
        if count == 0:
            print("   ⏩ AppSettings 초기 데이터 삽입 중...")
            cursor.execute("""
                INSERT INTO dbo.AppSettings (Id, ServerUrl, ApiKey, UpdatedAt)
                VALUES (1, ?, ?, SYSUTCDATETIME())
            """, ('http://25.2.89.129:8000', ''))
            conn.commit()
            print("   ✅ AppSettings 삽입 완료")
        else:
            print("   ℹ️  AppSettings 데이터가 이미 존재합니다.")
            cursor.execute("SELECT ServerUrl, ApiKey FROM dbo.AppSettings WHERE Id = 1")
            row = cursor.fetchone()
            print(f"      ServerUrl: {row[0]}")
            print(f"      ApiKey: {row[1] if row[1] else '(없음)'}")
        
        # SmtpConfig 체크 및 삽입
        print("\n[2] SmtpConfig 테이블 확인...")
        cursor.execute("SELECT COUNT(*) FROM dbo.SmtpConfig WHERE Id = 1")
        count = cursor.fetchone()[0]
        
        if count == 0:
            print("   ⏩ SmtpConfig 초기 데이터 삽입 중...")
            cursor.execute("""
                INSERT INTO dbo.SmtpConfig (Id, Host, Port, Username, Password, UseSSL, UpdatedAt)
                VALUES (1, ?, ?, ?, ?, ?, SYSUTCDATETIME())
            """, ('smtp.gmail.com', 587, '', '', 1))
            conn.commit()
            print("   ✅ SmtpConfig 삽입 완료")
        else:
            print("   ℹ️  SmtpConfig 데이터가 이미 존재합니다.")
            cursor.execute("SELECT Host, Port, Username, UseSSL FROM dbo.SmtpConfig WHERE Id = 1")
            row = cursor.fetchone()
            print(f"      Host: {row[0]}")
            print(f"      Port: {row[1]}")
            print(f"      Username: {row[2] if row[2] else '(없음)'}")
            print(f"      UseSSL: {'예' if row[3] else '아니오'}")
        
        cursor.close()
        conn.close()
        
        print("\n" + "=" * 60)
        print("✅ DB 초기화 완료!")
        print("=" * 60)
        
    except pyodbc.Error as e:
        print(f"\n❌ DB 연결 실패: {e}")
        return False
    except Exception as e:
        print(f"\n❌ 에러 발생: {e}")
        return False
    
    return True

if __name__ == "__main__":
    success = init_db()
    exit(0 if success else 1)
