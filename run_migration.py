import pyodbc
import os

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
    "Connection Timeout=10;"
)

# SQL 파일 읽기
with open('db_migration_add_master_fields.sql', 'r', encoding='utf-8') as f:
    sql_script = f.read()

# GO로 구분하여 실행
statements = sql_script.split('GO')

try:
    conn = pyodbc.connect(conn_str)
    cursor = conn.cursor()
    
    print(f"DB 연결 성공: {DB_SERVER}")
    print("")
    
    for i, statement in enumerate(statements):
        statement = statement.strip()
        if not statement:
            continue
            
        try:
            cursor.execute(statement)
            conn.commit()
            
            # PRINT 문의 출력 가져오기
            while cursor.nextset():
                pass
                
        except Exception as e:
            print(f"오류 발생 (Statement {i+1}): {e}")
            conn.rollback()
    
    cursor.close()
    conn.close()
    
    print("\n마이그레이션 완료!")
    
except Exception as e:
    print(f"DB 연결 실패: {e}")
    exit(1)
