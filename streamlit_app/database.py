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

CONN_STR = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={DB_SERVER},{DB_PORT};"
    f"DATABASE={DB_NAME};"
    f"UID={DB_USER};PWD={DB_PASSWORD};"
    "TrustServerCertificate=YES;"
    "Encrypt=YES;"
    "Connection Timeout=5;"
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
