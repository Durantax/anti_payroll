"""
DB 스키마 동기화 도구
- DB의 현재 테이블/컬럼 구조를 읽어옵니다
- script_additions.sql과 비교하여 누락된 것만 추가합니다
- 기존 데이터는 절대 삭제하지 않습니다 (추가만 가능)
"""

import pyodbc
import os
import re
from typing import Dict, List, Set

# DB 연결 정보
DB_SERVER = os.getenv("DB_SERVER", "25.2.89.129")
DB_PORT = os.getenv("DB_PORT", "1433")
DB_NAME = os.getenv("DB_NAME", "기본정보")
DB_USER = os.getenv("DB_USER", "sa")
DB_PASSWORD = os.getenv("DB_PASSWORD", "Playtest123!")

def get_connection():
    """DB 연결"""
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
        print(f"✅ DB 연결 성공")
        return conn
    except Exception as e:
        print(f"❌ DB 연결 실패: {e}")
        raise

def get_all_tables(conn) -> Dict[str, List[Dict]]:
    """모든 테이블과 컬럼 정보 가져오기"""
    cur = conn.cursor()
    
    # 테이블 목록
    cur.execute("""
        SELECT TABLE_NAME 
        FROM INFORMATION_SCHEMA.TABLES 
        WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA = 'dbo'
        ORDER BY TABLE_NAME
    """)
    
    tables = {}
    
    for row in cur.fetchall():
        table_name = row[0]
        
        # 각 테이블의 컬럼 정보
        cur.execute("""
            SELECT 
                COLUMN_NAME,
                DATA_TYPE,
                CHARACTER_MAXIMUM_LENGTH,
                NUMERIC_PRECISION,
                NUMERIC_SCALE,
                IS_NULLABLE,
                COLUMN_DEFAULT
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_NAME = ? AND TABLE_SCHEMA = 'dbo'
            ORDER BY ORDINAL_POSITION
        """, (table_name,))
        
        columns = []
        for col in cur.fetchall():
            columns.append({
                'name': col[0],
                'type': col[1],
                'max_length': col[2],
                'precision': col[3],
                'scale': col[4],
                'nullable': col[5],
                'default': col[6]
            })
        
        tables[table_name] = columns
    
    return tables

def get_indexes(conn, table_name: str) -> List[Dict]:
    """특정 테이블의 인덱스 정보"""
    cur = conn.cursor()
    cur.execute("""
        SELECT 
            i.name AS index_name,
            i.is_unique,
            i.is_primary_key,
            COL_NAME(ic.object_id, ic.column_id) AS column_name
        FROM sys.indexes i
        INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        WHERE i.object_id = OBJECT_ID(?)
        ORDER BY i.name, ic.key_ordinal
    """, (f'dbo.{table_name}',))
    
    indexes = []
    for row in cur.fetchall():
        indexes.append({
            'name': row[0],
            'unique': row[1],
            'primary': row[2],
            'column': row[3]
        })
    
    return indexes

def get_triggers(conn) -> List[Dict]:
    """모든 트리거 정보"""
    cur = conn.cursor()
    cur.execute("""
        SELECT 
            t.name AS trigger_name,
            OBJECT_NAME(t.parent_id) AS table_name,
            t.is_disabled
        FROM sys.triggers t
        WHERE t.parent_class = 1
        ORDER BY table_name, trigger_name
    """)
    
    triggers = []
    for row in cur.fetchall():
        triggers.append({
            'name': row[0],
            'table': row[1],
            'disabled': row[2]
        })
    
    return triggers

def parse_script_sql(filepath: str) -> Dict[str, Set[str]]:
    """script_additions.sql에서 필요한 테이블/컬럼 파싱"""
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        content = f.read()
    
    required = {}
    
    # CREATE TABLE 분석
    create_pattern = r'CREATE TABLE dbo\.(\w+)\s*\((.*?)\);'
    for match in re.finditer(create_pattern, content, re.DOTALL | re.IGNORECASE):
        table_name = match.group(1)
        columns_block = match.group(2)
        
        columns = set()
        # 컬럼명 추출 (간단한 버전)
        for line in columns_block.split('\n'):
            line = line.strip()
            if line and not line.startswith('--') and not line.upper().startswith('CONSTRAINT'):
                parts = line.split()
                if parts:
                    col_name = parts[0].strip(',')
                    if col_name and not col_name.upper() in ['PRIMARY', 'FOREIGN', 'CHECK', 'UNIQUE']:
                        columns.add(col_name)
        
        required[table_name] = columns
    
    # ALTER TABLE ADD 분석
    alter_pattern = r'ALTER TABLE dbo\.(\w+) ADD (\w+)'
    for match in re.finditer(alter_pattern, content, re.IGNORECASE):
        table_name = match.group(1)
        column_name = match.group(2)
        
        if table_name not in required:
            required[table_name] = set()
        required[table_name].add(column_name)
    
    return required

def check_and_sync():
    """DB 스키마 체크 및 동기화"""
    print("=" * 60)
    print("DB 스키마 동기화 도구")
    print("=" * 60)
    
    conn = get_connection()
    
    # 1. 현재 DB 구조 읽기
    print("\n📊 현재 DB 구조 읽는 중...")
    current_tables = get_all_tables(conn)
    print(f"   총 {len(current_tables)}개 테이블 발견")
    
    # 2. 필요한 구조 파싱
    print("\n📋 script_additions.sql 분석 중...")
    required_tables = parse_script_sql('script_additions.sql')
    print(f"   총 {len(required_tables)}개 테이블 정의됨")
    
    # 3. 비교 및 차이점 표시
    print("\n🔍 차이점 분석:")
    missing_tables = []
    missing_columns = {}
    
    for table_name, required_cols in required_tables.items():
        if table_name not in current_tables:
            missing_tables.append(table_name)
            print(f"   ❌ 테이블 누락: {table_name}")
        else:
            current_cols = set(col['name'] for col in current_tables[table_name])
            missing = required_cols - current_cols
            
            if missing:
                missing_columns[table_name] = missing
                print(f"   ⚠️  {table_name}: {len(missing)}개 컬럼 누락 - {', '.join(missing)}")
    
    # 4. 추가 정보
    print("\n📌 기타 정보:")
    triggers = get_triggers(conn)
    print(f"   트리거: {len(triggers)}개")
    for t in triggers:
        status = "비활성" if t['disabled'] else "활성"
        print(f"      - {t['table']}.{t['name']} ({status})")
    
    # 5. 요약
    print("\n" + "=" * 60)
    print("요약:")
    print(f"  누락된 테이블: {len(missing_tables)}개")
    print(f"  컬럼 누락된 테이블: {len(missing_columns)}개")
    
    if missing_tables or missing_columns:
        print("\n💡 해결 방법:")
        print("   python db_remote_manager.py")
        print("   를 실행하여 누락된 테이블/컬럼을 추가하세요.")
    else:
        print("\n✅ DB 스키마가 최신 상태입니다!")
    
    print("=" * 60)
    
    conn.close()

if __name__ == "__main__":
    try:
        check_and_sync()
    except Exception as e:
        print(f"\n❌ 에러 발생: {e}")
        import traceback
        traceback.print_exc()
