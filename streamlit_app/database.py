"""
데이터베이스 연결 및 기본 설정
"""
import pyodbc
import streamlit as st
from typing import Dict, List, Any, Optional
import os

# DB 연결 설정
DB_SERVER = os.getenv("DB_SERVER", "25.2.89.129")
DB_PORT = os.getenv("DB_PORT", "1433")
DB_NAME = os.getenv("DB_NAME", "기본정보")
DB_USER = os.getenv("DB_USER", "user1")
DB_PASSWORD = os.getenv("DB_PASSWORD", "1536")

# ODBC 드라이버 자동 감지
def get_odbc_driver():
    """사용 가능한 ODBC 드라이버 찾기"""
    drivers = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "ODBC Driver 13 for SQL Server",
        "ODBC Driver 11 for SQL Server",
        "SQL Server Native Client 11.0",
        "SQL Server",
    ]
    
    try:
        available_drivers = pyodbc.drivers()
        for driver in drivers:
            if driver in available_drivers:
                return driver
        # 사용 가능한 첫 번째 SQL Server 드라이버 사용
        for driver in available_drivers:
            if 'SQL Server' in driver:
                return driver
        return None
    except:
        return drivers[0]  # 기본값

ODBC_DRIVER = get_odbc_driver()

if ODBC_DRIVER:
    CONN_STR = (
        f"DRIVER={{{ODBC_DRIVER}}};"
        f"SERVER={DB_SERVER},{DB_PORT};"
        f"DATABASE={DB_NAME};"
        f"UID={DB_USER};PWD={DB_PASSWORD};"
        "TrustServerCertificate=YES;"
        "Encrypt=YES;"
        "Connection Timeout=10;"
    )
else:
    # 드라이버를 찾을 수 없는 경우 기본 연결 문자열
    CONN_STR = (
        f"DRIVER={{SQL Server}};"
        f"SERVER={DB_SERVER},{DB_PORT};"
        f"DATABASE={DB_NAME};"
        f"UID={DB_USER};PWD={DB_PASSWORD};"
        "Connection Timeout=10;"
    )


@st.cache_resource
def get_db_connection():
    """DB 연결 (캐시됨)"""
    try:
        return pyodbc.connect(CONN_STR)
    except Exception as e:
        st.error(f"❌ DB 연결 실패: {e}")
        return None


def execute_query(sql: str, params: tuple = ()) -> int:
    """SQL 실행 (INSERT, UPDATE, DELETE)"""
    conn = get_db_connection()
    if not conn:
        raise Exception("DB 연결 없음")
    
    cursor = conn.cursor()
    cursor.execute(sql, params)
    rowcount = cursor.rowcount
    conn.commit()
    return rowcount


def fetch_all(sql: str, params: tuple = ()) -> List[Dict[str, Any]]:
    """SQL 조회 (SELECT)"""
    conn = get_db_connection()
    if not conn:
        return []
    
    cursor = conn.cursor()
    cursor.execute(sql, params)
    
    columns = [column[0] for column in cursor.description]
    results = []
    
    for row in cursor.fetchall():
        results.append(dict(zip(columns, row)))
    
    return results


def fetch_one(sql: str, params: tuple = ()) -> Optional[Dict[str, Any]]:
    """SQL 조회 (단일 행)"""
    results = fetch_all(sql, params)
    return results[0] if results else None


def get_database_info() -> Dict[str, Any]:
    """데이터베이스 연결 정보 및 진단"""
    info = {
        'server': DB_SERVER,
        'port': DB_PORT,
        'database': DB_NAME,
        'user': DB_USER,
        'odbc_driver': ODBC_DRIVER,
        'available_drivers': [],
        'connection_string': CONN_STR,
        'connection_status': 'Unknown',
        'connection_error': None
    }
    
    try:
        # 사용 가능한 모든 ODBC 드라이버 목록
        info['available_drivers'] = pyodbc.drivers()
    except Exception as e:
        info['available_drivers'] = [f"드라이버 목록 조회 실패: {e}"]
    
    # 연결 테스트
    try:
        conn = pyodbc.connect(CONN_STR)
        conn.close()
        info['connection_status'] = 'Success'
    except Exception as e:
        info['connection_status'] = 'Failed'
        info['connection_error'] = str(e)
    
    return info
