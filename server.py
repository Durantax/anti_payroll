# server.py
# FastAPI + MSSQL(pyodbc) - 완전 업데이트 버전
# Durantax 급여관리 시스템 백엔드 서버
# 
# ✅ 주요 기능:
# - 거래처 관리 (이메일 템플릿 포함)
# - 직원 관리 (4대보험, 세액계산, 입퇴사일, 사번)
# - 월별 급여 입력 (근무시간, 초과근무, 두루누리)
# - 급여 계산 결과 저장/조회
# - 발송 현황 관리
# - 로그 관리 (문서 로그, 메일 로그, 급여발송로그)
# - SMTP 설정
# - 공휴일 API 연동

from __future__ import annotations
import sys
import os
import re
import smtplib
import xml.etree.ElementTree as ET
from email.message import EmailMessage
from datetime import datetime, date, timedelta, timezone
from typing import Optional, List, Literal, Dict, Any
from contextlib import asynccontextmanager
from typing import AsyncGenerator
import json

import pyodbc
import requests
from fastapi import FastAPI, HTTPException, Header, Depends, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


# =========================
# 환경변수
# =========================
DB_SERVER = os.getenv("DB_SERVER", "25.2.89.129")
DB_PORT = os.getenv("DB_PORT", "1433")
DB_NAME = os.getenv("DB_NAME", "기본정보")
DB_USER = os.getenv("DB_USER", "user1")
DB_PASSWORD = os.getenv("DB_PASSWORD", "1536")

API_KEY = os.getenv("API_KEY", "")
INIT_DB = os.getenv("INIT_DB", "0") == "1"  # 기본값 0으로 변경 (기존 DB 사용)

SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
SMTP_STARTTLS = os.getenv("SMTP_STARTTLS", "1") == "1"
SMTP_SSL = os.getenv("SMTP_SSL", "0") == "1"
MAIL_FROM = os.getenv("MAIL_FROM", SMTP_USER)

KST = timezone(timedelta(hours=9))

HOLIDAY_SERVICE_KEY = os.getenv(
    "HOLIDAY_SERVICE_KEY",
    "2%2F1UDN4j8KrYtjV1VQTu%2B5grpvp4oQpvMoXrIuR3zJ4I74V%2FZAE0siRwZjyfQZlq5u53wDzqk%2BPTqKeLU1FRrA%3D%3D",
)

_HOLIDAY_ENDPOINTS = [
    "https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo",
    "http://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo",
]

_HOLIDAY_CACHE: Dict[int, set[date]] = {}
_HOLIDAY_CACHE_ERR: Dict[int, str] = {}


# =========================
# ODBC 연결
# =========================
CONN_STR = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={DB_SERVER},{DB_PORT};"
    f"DATABASE={DB_NAME};"
    f"UID={DB_USER};PWD={DB_PASSWORD};"
    "TrustServerCertificate=YES;"
    "Encrypt=YES;"
    "Connection Timeout=5;"
)


def get_conn() -> pyodbc.Connection:
    return pyodbc.connect(CONN_STR)


def exec_sql(conn: pyodbc.Connection, sql: str, params: tuple = ()) -> int:
    cur = conn.cursor()
    cur.execute(sql, params)
    rowcount = cur.rowcount
    conn.commit()
    return rowcount


def fetch_all(conn: pyodbc.Connection, sql: str, params: tuple = ()) -> List[Dict[str, Any]]:
    cur = conn.cursor()
    cur.execute(sql, params)
    cols = [c[0] for c in cur.description]
    rows = []
    for r in cur.fetchall():
        rows.append({cols[i]: r[i] for i in range(len(cols))})
    return rows


def fetch_one(conn: pyodbc.Connection, sql: str, params: tuple = ()) -> Optional[Dict[str, Any]]:
    cur = conn.cursor()
    cur.execute(sql, params)
    row = cur.fetchone()
    if not row:
        return None
    cols = [c[0] for c in cur.description]
    return {cols[i]: row[i] for i in range(len(cols))}


def object_exists(conn: pyodbc.Connection, full_name: str, obj_type: str) -> bool:
    """
    obj_type:
      - 'U' = User Table
      - 'V' = View
    """
    if "." not in full_name:
        schema = "dbo"
        name = full_name
    else:
        schema, name = full_name.split(".", 1)

    row = fetch_one(
        conn,
        "SELECT 1 AS ok FROM sys.objects o "
        "JOIN sys.schemas s ON o.schema_id = s.schema_id "
        "WHERE o.type=? AND s.name=? AND o.name=?",
        (obj_type, schema, name),
    )
    return bool(row and row.get("ok") == 1)


def table_exists(conn: pyodbc.Connection, full_name: str) -> bool:
    return object_exists(conn, full_name, "U")


def view_exists(conn: pyodbc.Connection, full_name: str) -> bool:
    return object_exists(conn, full_name, "V")


def column_exists(conn: pyodbc.Connection, table_name: str, column_name: str) -> bool:
    """테이블에 컬럼이 있는지 확인"""
    row = fetch_one(
        conn,
        "SELECT 1 AS ok FROM sys.columns "
        "WHERE object_id = OBJECT_ID(?) AND name = ?",
        (table_name, column_name),
    )
    return bool(row and row.get("ok") == 1)


# =========================
# 유틸
# =========================
def now_utc() -> str:
    return datetime.utcnow().isoformat(timespec="seconds")


def now_kst() -> datetime:
    return datetime.now(tz=KST)


def today_kst() -> date:
    return now_kst().date()


def safe_int(v) -> Optional[int]:
    if v is None:
        return None
    s = str(v).strip()
    if s == "":
        return None
    if not re.match(r"^\d+$", s):
        return None
    try:
        return int(s)
    except Exception:
        return None


def ym_of(d: date) -> str:
    return f"{d.year:04d}-{d.month:02d}"


def require_api_key(x_api_key: Optional[str] = Header(default=None, alias="X-API-Key")):
    if API_KEY:
        if not x_api_key or x_api_key != API_KEY:
            raise HTTPException(status_code=401, detail="Invalid API key")
    return True


# =========================
# 공휴일 API
# =========================
def fetch_holidays(year: int) -> set[date]:
    if year in _HOLIDAY_CACHE:
        return _HOLIDAY_CACHE[year]

    holidays: set[date] = set()

    if not HOLIDAY_SERVICE_KEY or not str(HOLIDAY_SERVICE_KEY).strip():
        _HOLIDAY_CACHE[year] = holidays
        _HOLIDAY_CACHE_ERR[year] = "HOLIDAY_SERVICE_KEY is empty"
        return holidays

    last_err: Optional[str] = None

    for month in range(1, 13):
        sol_month = f"{month:02d}"
        month_ok = False
        for ep in _HOLIDAY_ENDPOINTS:
            try:
                params = {
                    "ServiceKey": HOLIDAY_SERVICE_KEY,
                    "solYear": str(year),
                    "solMonth": sol_month,
                    "_type": "xml",
                }
                r = requests.get(ep, params=params, timeout=5)
                r.raise_for_status()

                root = ET.fromstring(r.text)
                result_code = root.findtext(".//resultCode")
                result_msg = root.findtext(".//resultMsg")
                if result_code and result_code != "00":
                    last_err = f"{result_code}:{result_msg}"
                    continue

                for e in root.findall(".//item/locdate"):
                    if e is None or not e.text:
                        continue
                    s = e.text.strip()
                    if re.match(r"^\d{8}$", s):
                        y = int(s[0:4])
                        m = int(s[4:6])
                        d = int(s[6:8])
                        holidays.add(date(y, m, d))

                month_ok = True
                break

            except Exception as ex:
                last_err = str(ex)

        if not month_ok:
            continue

    _HOLIDAY_CACHE[year] = holidays
    if last_err:
        _HOLIDAY_CACHE_ERR[year] = last_err
    return holidays


def is_business_day(d: date) -> bool:
    if d.weekday() >= 5:
        return False
    holidays = fetch_holidays(d.year)
    return d not in holidays


def adjust_to_workday(d: date) -> date:
    while not is_business_day(d):
        d = d - timedelta(days=1)
    return d


# =========================
# Pydantic DTO
# =========================
class ClientOut(BaseModel):
    id: int
    name: str
    bizId: str
    slipSendDay: Optional[int] = None
    registerSendDay: Optional[int] = None
    has5OrMoreWorkers: bool = False
    emailSubjectTemplate: str = "{clientName} {year}년 {month}월 {workerName} 급여명세서"
    emailBodyTemplate: str = "안녕하세요,\n\n{year}년 {month}월 급여명세서를 발송드립니다.\n\n감사합니다."


class ClientUpdateIn(BaseModel):
    has5OrMoreWorkers: Optional[bool] = None
    emailSubjectTemplate: Optional[str] = None
    emailBodyTemplate: Optional[str] = None


class EmployeeUpsertIn(BaseModel):
    clientId: int
    name: str
    birthDate: str = Field(..., description="YYYYMMDD or any string")
    employmentType: Literal["regular", "freelance"] = "regular"
    salaryType: Literal["MONTHLY", "HOURLY"] = "HOURLY"
    baseSalary: float = 0
    hourlyRate: float = 0
    normalHours: float = 209
    foodAllowance: float = 0
    carAllowance: float = 0
    emailTo: Optional[str] = None
    emailCc: Optional[str] = None
    useEmail: bool = False
    hasNationalPension: bool = True
    hasHealthInsurance: bool = True
    hasEmploymentInsurance: bool = True
    healthInsuranceBasis: Literal["salary", "insurable"] = "salary"
    pensionInsurableWage: Optional[float] = None

    joinDate: Optional[str] = None
    resignDate: Optional[str] = None

    taxDependents: int = 1
    childrenCount: int = 0
    taxFreeMeal: float = 0
    taxFreeCarMaintenance: float = 0
    otherTaxFree: float = 0
    incomeTaxRate: int = 100


class EmployeeOut(BaseModel):
    employeeId: int
    clientId: int
    empNo: Optional[str] = None
    name: str
    birthDate: str
    employmentType: str
    salaryType: str
    baseSalary: float
    hourlyRate: float
    normalHours: float
    foodAllowance: float
    carAllowance: float
    emailTo: Optional[str] = None
    emailCc: Optional[str] = None
    useEmail: bool
    hasNationalPension: bool
    hasHealthInsurance: bool
    hasEmploymentInsurance: bool
    healthInsuranceBasis: str
    pensionInsurableWage: Optional[float] = None

    joinDate: Optional[str] = None
    resignDate: Optional[str] = None

    taxDependents: int
    childrenCount: int
    taxFreeMeal: float
    taxFreeCarMaintenance: float
    otherTaxFree: float
    incomeTaxRate: int

    updatedAt: str


class MonthlyUpsertIn(BaseModel):
    employeeId: int
    ym: str = Field(..., description="YYYY-MM")
    workHours: float = 0
    bonus: float = 0
    overtimeHours: float = 0
    nightHours: float = 0
    holidayHours: float = 0
    weeklyHours: float = 40.0
    weekCount: int = 4
    isDurunuri: bool = False  # ✅ 두루누리 체크박스


class DocLogIn(BaseModel):
    clientId: int
    ym: str
    docType: Literal["register", "slip", "excel_request"]
    employeeId: Optional[int] = None
    fileName: str
    fileHash: Optional[str] = None
    localPath: Optional[str] = None
    pcId: Optional[str] = None


class MailLogIn(BaseModel):
    clientId: int
    ym: str
    docType: Literal["register", "slip"]
    toEmail: str
    subject: str
    status: Literal["sent", "failed"]
    errorMessage: Optional[str] = None
    ccEmail: Optional[str] = None
    employeeId: Optional[int] = None
    pcId: Optional[str] = None


# ✅ 급여발송로그 DTO
class PayrollSendLogIn(BaseModel):
    clientId: int
    ym: str
    docType: Literal["slip", "register"]
    sendResult: Literal["성공", "실패"]
    retryCount: int = 0
    errorMessage: Optional[str] = None
    recipient: Optional[str] = None
    ccRecipient: Optional[str] = None
    subject: Optional[str] = None
    sendMethod: Literal["자동", "수동"] = "자동"
    sendPath: str = "SMTP"
    executingPC: Optional[str] = None
    executor: str = "AUTO_SYSTEM"


class MailLogBulkIn(BaseModel):
    items: List[MailLogIn]


class MailSendIn(BaseModel):
    clientId: int
    ym: str
    docType: Literal["register", "slip"]
    toEmail: str
    subject: str
    bodyText: str
    ccEmail: Optional[str] = None
    employeeId: Optional[int] = None
    pcId: Optional[str] = None


class TodayClientOut(BaseModel):
    clientId: int
    name: str
    bizId: str
    ym: str
    docType: Literal["slip", "register"]
    dueDate: str
    totalTargets: int
    sentTargets: int
    isDone: bool


class ClientSendStatusEmployeeOut(BaseModel):
    employeeId: int
    name: str
    birthDate: str
    useEmail: bool
    emailTo: Optional[str] = None
    emailCc: Optional[str] = None
    lastStatus: Optional[str] = None
    lastSentAt: Optional[str] = None
    lastError: Optional[str] = None
    isSent: bool


class ClientSendStatusOut(BaseModel):
    clientId: int
    ym: str
    docType: Literal["slip", "register"]
    totalTargets: int
    sentTargets: int
    isDone: bool
    employees: List[ClientSendStatusEmployeeOut]


class SmtpConfigOut(BaseModel):
    host: str
    port: int
    username: str
    password: str
    useSSL: bool
    updatedAt: str


class SmtpConfigIn(BaseModel):
    host: str
    port: int = 587
    username: str
    password: str
    useSSL: bool = True


class AppSettingsOut(BaseModel):
    serverUrl: str
    apiKey: Optional[str] = None
    updatedAt: str


class AppSettingsIn(BaseModel):
    serverUrl: str
    apiKey: Optional[str] = None


# ✅ 거래처별 수당 항목 관리
class AllowanceMasterIn(BaseModel):
    allowanceName: str
    isActive: bool = True


class AllowanceMasterOut(BaseModel):
    allowanceId: int
    clientId: int
    allowanceName: str
    isActive: bool
    createdAt: str


# ✅ 거래처별 공제 항목 관리
class DeductionMasterIn(BaseModel):
    deductionName: str
    isActive: bool = True


class DeductionMasterOut(BaseModel):
    deductionId: int
    clientId: int
    deductionName: str
    isActive: bool
    createdAt: str


# ✅ 급여 결과 확정 상태
class ConfirmationStatusOut(BaseModel):
    resultId: int
    employeeId: int
    employeeName: str
    isConfirmed: bool
    confirmedAt: Optional[str] = None
    confirmedBy: Optional[str] = None


# =========================
# FastAPI 앱
# =========================
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    print(f"[BOOT] Durantax Payroll API v3.0.0 starting...")
    print(f"[BOOT] DB: {DB_SERVER}:{DB_PORT}/{DB_NAME}")
    print(f"[BOOT] INIT_DB: {INIT_DB}")
    
    # 기존 DB 사용 시 INIT_DB=0으로 설정하면 테이블 생성 건너뜀
    if INIT_DB:
        print("[WARN] INIT_DB is enabled but should be disabled for existing DB")
    
    yield


app = FastAPI(title="Durantax Payroll API", version="3.0.0", lifespan=lifespan)

print("[BOOT] server file =", __file__)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    try:
        print(f"[REQ] {request.method} {request.url.path}{'?' + request.url.query if request.url.query else ''}")
    except Exception:
        pass
    return await call_next(request)


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/_routes")
def _routes():
    items: List[Dict[str, Any]] = []
    for r in app.routes:
        path = getattr(r, "path", None)
        methods = getattr(r, "methods", None)
        if not path:
            continue
        items.append({
            "path": str(path),
            "methods": sorted(list(methods)) if methods else [],
        })
    return sorted(items, key=lambda x: x["path"])


# =========================
# 헬스체크
# =========================
@app.get("/health", dependencies=[Depends(require_api_key)])
def health():
    try:
        conn = get_conn()
        row = fetch_one(conn, "SELECT 1 AS ok")
        conn.close()
        return {
            "ok": True,
            "db": bool(row and row.get("ok") == 1),
            "time": now_utc(),
            "holidayCacheYears": sorted(list(_HOLIDAY_CACHE.keys())),
            "holidayCacheErr": _HOLIDAY_CACHE_ERR,
        }
    except Exception as e:
        return {"ok": False, "db": False, "error": str(e), "time": now_utc()}


# =========================
# 거래처 조회/수정
# =========================
@app.get("/clients", response_model=List[ClientOut], dependencies=[Depends(require_api_key)])
def get_clients():
    conn = get_conn()
    try:
        has_5workers = column_exists(conn, "dbo.거래처", "Has5OrMoreWorkers")
        has_subject = column_exists(conn, "dbo.거래처", "EmailSubjectTemplate")
        has_body = column_exists(conn, "dbo.거래처", "EmailBodyTemplate")

        select_parts = [
            "ID AS id",
            "고객명 AS name",
            "사업자등록번호 AS bizId",
            "급여명세서발송일 AS slipSendDay",
            "급여대장일 AS registerSendDay",
        ]

        if has_5workers:
            select_parts.append("Has5OrMoreWorkers AS has5OrMoreWorkers")
        if has_subject:
            select_parts.append("EmailSubjectTemplate AS emailSubjectTemplate")
        if has_body:
            select_parts.append("EmailBodyTemplate AS emailBodyTemplate")

        sql = f"SELECT {', '.join(select_parts)} FROM 거래처 WHERE 원천세='O' AND 사용여부=1 ORDER BY 고객명"
        rows = fetch_all(conn, sql)

        for r in rows:
            r["slipSendDay"] = safe_int(r.get("slipSendDay"))
            r["registerSendDay"] = safe_int(r.get("registerSendDay"))

            if not has_5workers:
                r["has5OrMoreWorkers"] = False
            else:
                r["has5OrMoreWorkers"] = bool(r.get("has5OrMoreWorkers"))

            if not has_subject:
                r["emailSubjectTemplate"] = "{clientName} {year}년 {month}월 {workerName} 급여명세서"
            if not has_body:
                r["emailBodyTemplate"] = "안녕하세요,\n\n{year}년 {month}월 급여명세서를 발송드립니다.\n\n감사합니다."

        return rows
    finally:
        conn.close()


@app.patch("/clients/{client_id}", dependencies=[Depends(require_api_key)])
def update_client(client_id: int, body: ClientUpdateIn):
    """거래처 정보 수정 (5인 기준, 이메일 템플릿)"""
    conn = get_conn()
    try:
        updates = []
        params = []

        if body.has5OrMoreWorkers is not None:
            if column_exists(conn, "dbo.거래처", "Has5OrMoreWorkers"):
                updates.append("Has5OrMoreWorkers = ?")
                params.append(int(body.has5OrMoreWorkers))

        if body.emailSubjectTemplate is not None:
            if column_exists(conn, "dbo.거래처", "EmailSubjectTemplate"):
                updates.append("EmailSubjectTemplate = ?")
                params.append(body.emailSubjectTemplate)

        if body.emailBodyTemplate is not None:
            if column_exists(conn, "dbo.거래처", "EmailBodyTemplate"):
                updates.append("EmailBodyTemplate = ?")
                params.append(body.emailBodyTemplate)

        if not updates:
            raise HTTPException(status_code=400, detail="No valid fields to update")

        params.append(client_id)
        sql = f"UPDATE 거래처 SET {', '.join(updates)} WHERE ID = ?"
        exec_sql(conn, sql, tuple(params))

        return {"ok": True}
    finally:
        conn.close()


# =========================
# 직원 조회/업서트/삭제
# =========================
@app.get("/clients/{client_id}/employees", response_model=List[EmployeeOut], dependencies=[Depends(require_api_key)])
def get_employees(client_id: int):
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.Employees"):
            return []

        has_empno = column_exists(conn, "dbo.Employees", "EmpNo")
        has_pension = column_exists(conn, "dbo.Employees", "HasNationalPension")
        has_health = column_exists(conn, "dbo.Employees", "HasHealthInsurance")
        has_employment = column_exists(conn, "dbo.Employees", "HasEmploymentInsurance")
        has_basis = column_exists(conn, "dbo.Employees", "HealthInsuranceBasis")
        has_wage = column_exists(conn, "dbo.Employees", "PensionInsurableWage")
        has_tax_dependents = column_exists(conn, "dbo.Employees", "TaxDependents")
        has_children = column_exists(conn, "dbo.Employees", "ChildrenCount")
        has_tax_free_meal = column_exists(conn, "dbo.Employees", "TaxFreeMeal")
        has_tax_free_car = column_exists(conn, "dbo.Employees", "TaxFreeCarMaintenance")
        has_other_tax_free = column_exists(conn, "dbo.Employees", "OtherTaxFree")
        has_income_tax_rate = column_exists(conn, "dbo.Employees", "IncomeTaxRate")
        has_join_date = column_exists(conn, "dbo.Employees", "JoinDate")
        has_resign_date = column_exists(conn, "dbo.Employees", "ResignDate")

        select_parts = [
            "EmployeeId AS employeeId",
            "ClientId AS clientId",
            "Name AS name",
            "BirthDate AS birthDate",
        ]

        if has_empno:
            select_parts.append("EmpNo AS empNo")

        select_parts += [
            "EmploymentType AS employmentType",
            "SalaryType AS salaryType",
            "BaseSalary AS baseSalary",
            "HourlyRate AS hourlyRate",
            "NormalHours AS normalHours",
            "FoodAllowance AS foodAllowance",
            "CarAllowance AS carAllowance",
            "EmailTo AS emailTo",
            "EmailCc AS emailCc",
            "UseEmail AS useEmail",
        ]

        if has_pension:
            select_parts.append("HasNationalPension AS hasNationalPension")
        if has_health:
            select_parts.append("HasHealthInsurance AS hasHealthInsurance")
        if has_employment:
            select_parts.append("HasEmploymentInsurance AS hasEmploymentInsurance")
        if has_basis:
            select_parts.append("HealthInsuranceBasis AS healthInsuranceBasis")
        if has_wage:
            select_parts.append("PensionInsurableWage AS pensionInsurableWage")

        if has_tax_dependents:
            select_parts.append("TaxDependents AS taxDependents")
        if has_children:
            select_parts.append("ChildrenCount AS childrenCount")
        if has_tax_free_meal:
            select_parts.append("TaxFreeMeal AS taxFreeMeal")
        if has_tax_free_car:
            select_parts.append("TaxFreeCarMaintenance AS taxFreeCarMaintenance")
        if has_other_tax_free:
            select_parts.append("OtherTaxFree AS otherTaxFree")
        if has_income_tax_rate:
            select_parts.append("IncomeTaxRate AS incomeTaxRate")

        if has_join_date:
            select_parts.append("CONVERT(NVARCHAR(10), JoinDate, 23) AS joinDate")
        if has_resign_date:
            select_parts.append("CONVERT(NVARCHAR(10), ResignDate, 23) AS resignDate")

        select_parts.append("CONVERT(NVARCHAR(19), UpdatedAt, 126) AS updatedAt")

        sql = f"SELECT {', '.join(select_parts)} FROM dbo.Employees WHERE ClientId=? ORDER BY Name"
        rows = fetch_all(conn, sql, (client_id,))

        for r in rows:
            for k in ["baseSalary", "hourlyRate", "normalHours", "foodAllowance", "carAllowance"]:
                r[k] = float(r.get(k) or 0)
            r["useEmail"] = bool(r.get("useEmail"))

            if not has_empno:
                r["empNo"] = None
            else:
                v = r.get("empNo")
                r["empNo"] = str(v).strip() if v is not None else None

            if not has_pension:
                r["hasNationalPension"] = True
            else:
                r["hasNationalPension"] = bool(r.get("hasNationalPension"))

            if not has_health:
                r["hasHealthInsurance"] = True
            else:
                r["hasHealthInsurance"] = bool(r.get("hasHealthInsurance"))

            if not has_employment:
                r["hasEmploymentInsurance"] = True
            else:
                r["hasEmploymentInsurance"] = bool(r.get("hasEmploymentInsurance"))

            if not has_basis:
                r["healthInsuranceBasis"] = "salary"

            if not has_wage:
                r["pensionInsurableWage"] = None
            elif r.get("pensionInsurableWage") is not None:
                r["pensionInsurableWage"] = float(r.get("pensionInsurableWage") or 0)

            if not has_tax_dependents:
                r["taxDependents"] = 1
            if not has_children:
                r["childrenCount"] = 0

            if not has_tax_free_meal:
                r["taxFreeMeal"] = 0.0
            else:
                r["taxFreeMeal"] = float(r.get("taxFreeMeal") or 0)

            if not has_tax_free_car:
                r["taxFreeCarMaintenance"] = 0.0
            else:
                r["taxFreeCarMaintenance"] = float(r.get("taxFreeCarMaintenance") or 0)

            if not has_other_tax_free:
                r["otherTaxFree"] = 0.0
            else:
                r["otherTaxFree"] = float(r.get("otherTaxFree") or 0)

            if not has_income_tax_rate:
                r["incomeTaxRate"] = 100

            if not has_join_date:
                r["joinDate"] = None
            if not has_resign_date:
                r["resignDate"] = None

        return rows
    finally:
        conn.close()


@app.post("/employees/upsert", response_model=EmployeeOut, dependencies=[Depends(require_api_key)])
def upsert_employee(body: EmployeeUpsertIn):
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.Employees"):
            raise HTTPException(status_code=500, detail="dbo.Employees 테이블이 없습니다.")

        has_empno = column_exists(conn, "dbo.Employees", "EmpNo")
        has_pension = column_exists(conn, "dbo.Employees", "HasNationalPension")
        has_health = column_exists(conn, "dbo.Employees", "HasHealthInsurance")
        has_employment = column_exists(conn, "dbo.Employees", "HasEmploymentInsurance")
        has_basis = column_exists(conn, "dbo.Employees", "HealthInsuranceBasis")
        has_wage = column_exists(conn, "dbo.Employees", "PensionInsurableWage")
        has_tax_dependents = column_exists(conn, "dbo.Employees", "TaxDependents")
        has_children = column_exists(conn, "dbo.Employees", "ChildrenCount")
        has_tax_free_meal = column_exists(conn, "dbo.Employees", "TaxFreeMeal")
        has_tax_free_car = column_exists(conn, "dbo.Employees", "TaxFreeCarMaintenance")
        has_other_tax_free = column_exists(conn, "dbo.Employees", "OtherTaxFree")
        has_income_tax_rate = column_exists(conn, "dbo.Employees", "IncomeTaxRate")
        has_join_date = column_exists(conn, "dbo.Employees", "JoinDate")
        has_resign_date = column_exists(conn, "dbo.Employees", "ResignDate")

        update_sets = [
            "EmploymentType=?", "SalaryType=?", "BaseSalary=?", "HourlyRate=?", "NormalHours=?",
            "FoodAllowance=?", "CarAllowance=?", "EmailTo=?", "EmailCc=?", "UseEmail=?",
        ]
        insert_cols = [
            "ClientId", "Name", "BirthDate", "EmploymentType", "SalaryType", "BaseSalary",
            "HourlyRate", "NormalHours", "FoodAllowance", "CarAllowance", "EmailTo", "EmailCc", "UseEmail",
        ]
        insert_vals = ["?"] * 13

        params_update = [
            body.employmentType, body.salaryType, body.baseSalary, body.hourlyRate, body.normalHours,
            body.foodAllowance, body.carAllowance, body.emailTo, body.emailCc, int(body.useEmail),
        ]
        params_insert = [
            body.clientId, body.name, body.birthDate, body.employmentType, body.salaryType,
            body.baseSalary, body.hourlyRate, body.normalHours, body.foodAllowance, body.carAllowance,
            body.emailTo, body.emailCc, int(body.useEmail),
        ]

        if has_pension:
            update_sets.append("HasNationalPension=?")
            insert_cols.append("HasNationalPension")
            insert_vals.append("?")
            params_update.append(int(body.hasNationalPension))
            params_insert.append(int(body.hasNationalPension))

        if has_health:
            update_sets.append("HasHealthInsurance=?")
            insert_cols.append("HasHealthInsurance")
            insert_vals.append("?")
            params_update.append(int(body.hasHealthInsurance))
            params_insert.append(int(body.hasHealthInsurance))

        if has_employment:
            update_sets.append("HasEmploymentInsurance=?")
            insert_cols.append("HasEmploymentInsurance")
            insert_vals.append("?")
            params_update.append(int(body.hasEmploymentInsurance))
            params_insert.append(int(body.hasEmploymentInsurance))

        if has_basis:
            update_sets.append("HealthInsuranceBasis=?")
            insert_cols.append("HealthInsuranceBasis")
            insert_vals.append("?")
            params_update.append(body.healthInsuranceBasis)
            params_insert.append(body.healthInsuranceBasis)

        if has_wage:
            update_sets.append("PensionInsurableWage=?")
            insert_cols.append("PensionInsurableWage")
            insert_vals.append("?")
            params_update.append(body.pensionInsurableWage)
            params_insert.append(body.pensionInsurableWage)

        if has_join_date:
            update_sets.append("JoinDate=?")
            insert_cols.append("JoinDate")
            insert_vals.append("?")
            params_update.append(body.joinDate)
            params_insert.append(body.joinDate)

        if has_resign_date:
            update_sets.append("ResignDate=?")
            insert_cols.append("ResignDate")
            insert_vals.append("?")
            params_update.append(body.resignDate)
            params_insert.append(body.resignDate)

        if has_tax_dependents:
            update_sets.append("TaxDependents=?")
            insert_cols.append("TaxDependents")
            insert_vals.append("?")
            params_update.append(body.taxDependents)
            params_insert.append(body.taxDependents)

        if has_children:
            update_sets.append("ChildrenCount=?")
            insert_cols.append("ChildrenCount")
            insert_vals.append("?")
            params_update.append(body.childrenCount)
            params_insert.append(body.childrenCount)

        if has_tax_free_meal:
            update_sets.append("TaxFreeMeal=?")
            insert_cols.append("TaxFreeMeal")
            insert_vals.append("?")
            params_update.append(body.taxFreeMeal)
            params_insert.append(body.taxFreeMeal)

        if has_tax_free_car:
            update_sets.append("TaxFreeCarMaintenance=?")
            insert_cols.append("TaxFreeCarMaintenance")
            insert_vals.append("?")
            params_update.append(body.taxFreeCarMaintenance)
            params_insert.append(body.taxFreeCarMaintenance)

        if has_other_tax_free:
            update_sets.append("OtherTaxFree=?")
            insert_cols.append("OtherTaxFree")
            insert_vals.append("?")
            params_update.append(body.otherTaxFree)
            params_insert.append(body.otherTaxFree)

        if has_income_tax_rate:
            update_sets.append("IncomeTaxRate=?")
            insert_cols.append("IncomeTaxRate")
            insert_vals.append("?")
            params_update.append(body.incomeTaxRate)
            params_insert.append(body.incomeTaxRate)

        update_sets.append("UpdatedAt=SYSUTCDATETIME()")

        sql = f"""
        MERGE dbo.Employees AS t
        USING (SELECT ? AS ClientId, ? AS Name, ? AS BirthDate) AS s
        ON (t.ClientId=s.ClientId AND t.Name=s.Name AND t.BirthDate=s.BirthDate)
        WHEN MATCHED THEN
            UPDATE SET {', '.join(update_sets)}
        WHEN NOT MATCHED THEN
            INSERT ({', '.join(insert_cols)})
            VALUES ({', '.join(insert_vals)})
        OUTPUT inserted.EmployeeId AS employeeId;
        """

        params = (body.clientId, body.name, body.birthDate) + tuple(params_update) + tuple(params_insert)

        cur = conn.cursor()
        cur.execute(sql, params)
        out = cur.fetchone()
        conn.commit()

        if not out:
            raise HTTPException(status_code=500, detail="Upsert failed")

        employee_id = int(out[0])

        # SELECT로 다시 읽기 (EmpNo 트리거 반영)
        select_parts = [
            "EmployeeId AS employeeId",
            "ClientId AS clientId",
            "Name AS name",
            "BirthDate AS birthDate",
        ]
        if has_empno:
            select_parts.append("EmpNo AS empNo")

        select_parts += [
            "EmploymentType AS employmentType",
            "SalaryType AS salaryType",
            "BaseSalary AS baseSalary",
            "HourlyRate AS hourlyRate",
            "NormalHours AS normalHours",
            "FoodAllowance AS foodAllowance",
            "CarAllowance AS carAllowance",
            "EmailTo AS emailTo",
            "EmailCc AS emailCc",
            "UseEmail AS useEmail",
        ]

        if has_pension:
            select_parts.append("HasNationalPension AS hasNationalPension")
        if has_health:
            select_parts.append("HasHealthInsurance AS hasHealthInsurance")
        if has_employment:
            select_parts.append("HasEmploymentInsurance AS hasEmploymentInsurance")
        if has_basis:
            select_parts.append("HealthInsuranceBasis AS healthInsuranceBasis")
        if has_wage:
            select_parts.append("PensionInsurableWage AS pensionInsurableWage")

        if has_tax_dependents:
            select_parts.append("TaxDependents AS taxDependents")
        if has_children:
            select_parts.append("ChildrenCount AS childrenCount")
        if has_tax_free_meal:
            select_parts.append("TaxFreeMeal AS taxFreeMeal")
        if has_tax_free_car:
            select_parts.append("TaxFreeCarMaintenance AS taxFreeCarMaintenance")
        if has_other_tax_free:
            select_parts.append("OtherTaxFree AS otherTaxFree")
        if has_income_tax_rate:
            select_parts.append("IncomeTaxRate AS incomeTaxRate")

        if has_join_date:
            select_parts.append("CONVERT(NVARCHAR(10), JoinDate, 23) AS joinDate")
        if has_resign_date:
            select_parts.append("CONVERT(NVARCHAR(10), ResignDate, 23) AS resignDate")

        select_parts.append("CONVERT(NVARCHAR(19), UpdatedAt, 126) AS updatedAt")

        sql_select = f"SELECT {', '.join(select_parts)} FROM dbo.Employees WHERE EmployeeId=?"
        row = fetch_one(conn, sql_select, (employee_id,))
        if not row:
            raise HTTPException(status_code=404, detail="Employee not found after upsert")

        for k in ["baseSalary", "hourlyRate", "normalHours", "foodAllowance", "carAllowance"]:
            row[k] = float(row.get(k) or 0)
        row["useEmail"] = bool(row.get("useEmail"))

        if not has_empno:
            row["empNo"] = None
        else:
            v = row.get("empNo")
            row["empNo"] = str(v).strip() if v is not None else None

        if not has_pension:
            row["hasNationalPension"] = True
        else:
            row["hasNationalPension"] = bool(row.get("hasNationalPension"))

        if not has_health:
            row["hasHealthInsurance"] = True
        else:
            row["hasHealthInsurance"] = bool(row.get("hasHealthInsurance"))

        if not has_employment:
            row["hasEmploymentInsurance"] = True
        else:
            row["hasEmploymentInsurance"] = bool(row.get("hasEmploymentInsurance"))

        if not has_basis:
            row["healthInsuranceBasis"] = "salary"

        if not has_wage:
            row["pensionInsurableWage"] = None
        elif row.get("pensionInsurableWage") is not None:
            row["pensionInsurableWage"] = float(row.get("pensionInsurableWage") or 0)

        if not has_tax_dependents:
            row["taxDependents"] = 1
        if not has_children:
            row["childrenCount"] = 0

        if not has_tax_free_meal:
            row["taxFreeMeal"] = 0.0
        else:
            row["taxFreeMeal"] = float(row.get("taxFreeMeal") or 0)

        if not has_tax_free_car:
            row["taxFreeCarMaintenance"] = 0.0
        else:
            row["taxFreeCarMaintenance"] = float(row.get("taxFreeCarMaintenance") or 0)

        if not has_other_tax_free:
            row["otherTaxFree"] = 0.0
        else:
            row["otherTaxFree"] = float(row.get("otherTaxFree") or 0)

        if not has_income_tax_rate:
            row["incomeTaxRate"] = 100

        if not has_join_date:
            row["joinDate"] = None
        if not has_resign_date:
            row["resignDate"] = None

        return row

    finally:
        conn.close()


@app.get("/employees/{employee_id}/empno", dependencies=[Depends(require_api_key)])
def get_employee_empno(employee_id: int):
    """직원 사원번호(EmpNo) 단독 조회"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.Employees"):
            raise HTTPException(status_code=500, detail="dbo.Employees 테이블이 없습니다.")

        has_empno = column_exists(conn, "dbo.Employees", "EmpNo")
        if not has_empno:
            return {"employeeId": employee_id, "empNo": None}

        row = fetch_one(
            conn,
            "SELECT EmployeeId AS employeeId, ClientId AS clientId, EmpNo AS empNo "
            "FROM dbo.Employees WHERE EmployeeId=?",
            (employee_id,),
        )
        if not row:
            raise HTTPException(status_code=404, detail="Employee not found")

        v = row.get("empNo")
        return {
            "employeeId": int(row["employeeId"]),
            "clientId": int(row.get("clientId") or 0),
            "empNo": (str(v).strip() if v is not None else None),
        }
    finally:
        conn.close()


@app.delete("/employees/{employee_id}", dependencies=[Depends(require_api_key)])
def delete_employee(employee_id: int):
    """직원 삭제"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.Employees"):
            raise HTTPException(status_code=500, detail="dbo.Employees 테이블이 없습니다.")

        exec_sql(conn, "DELETE FROM dbo.Employees WHERE EmployeeId=?", (employee_id,))
        return {"ok": True}
    finally:
        conn.close()


# =========================
# 월별 입력값
# =========================
@app.post("/payroll/monthly/upsert", dependencies=[Depends(require_api_key)])
def upsert_monthly(body: MonthlyUpsertIn):
    if not re.match(r"^\d{4}-\d{2}$", body.ym):
        raise HTTPException(status_code=400, detail="ym must be YYYY-MM")

    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollMonthlyInput"):
            raise HTTPException(status_code=500, detail="dbo.PayrollMonthlyInput 테이블이 없습니다.")

        # ✅ IsDurunuri 컬럼 존재 여부 확인
        has_is_durunuri = column_exists(conn, "dbo.PayrollMonthlyInput", "IsDurunuri")

        if has_is_durunuri:
            sql = """
            MERGE dbo.PayrollMonthlyInput AS t
            USING (SELECT ? AS EmployeeId, ? AS Ym) AS s
            ON (t.EmployeeId=s.EmployeeId AND t.Ym=s.Ym)
            WHEN MATCHED THEN
                UPDATE SET
                  WorkHours=?,
                  Bonus=?,
                  OvertimeHours=?,
                  NightHours=?,
                  HolidayHours=?,
                  WeeklyHours=?,
                  WeekCount=?,
                  IsDurunuri=?,
                  UpdatedAt=SYSUTCDATETIME()
            WHEN NOT MATCHED THEN
                INSERT (EmployeeId, Ym, WorkHours, Bonus, OvertimeHours, NightHours, HolidayHours, WeeklyHours, WeekCount, IsDurunuri)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            params = (
                body.employeeId, body.ym,
                body.workHours, body.bonus, body.overtimeHours, body.nightHours, body.holidayHours,
                body.weeklyHours, body.weekCount, int(body.isDurunuri),
                body.employeeId, body.ym, body.workHours, body.bonus, body.overtimeHours, body.nightHours, body.holidayHours,
                body.weeklyHours, body.weekCount, int(body.isDurunuri),
            )
        else:
            sql = """
            MERGE dbo.PayrollMonthlyInput AS t
            USING (SELECT ? AS EmployeeId, ? AS Ym) AS s
            ON (t.EmployeeId=s.EmployeeId AND t.Ym=s.Ym)
            WHEN MATCHED THEN
                UPDATE SET
                  WorkHours=?,
                  Bonus=?,
                  OvertimeHours=?,
                  NightHours=?,
                  HolidayHours=?,
                  WeeklyHours=?,
                  WeekCount=?,
                  UpdatedAt=SYSUTCDATETIME()
            WHEN NOT MATCHED THEN
                INSERT (EmployeeId, Ym, WorkHours, Bonus, OvertimeHours, NightHours, HolidayHours, WeeklyHours, WeekCount)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            params = (
                body.employeeId, body.ym,
                body.workHours, body.bonus, body.overtimeHours, body.nightHours, body.holidayHours,
                body.weeklyHours, body.weekCount,
                body.employeeId, body.ym, body.workHours, body.bonus, body.overtimeHours, body.nightHours, body.holidayHours,
                body.weeklyHours, body.weekCount,
            )

        exec_sql(conn, sql, params)
        return {"ok": True}
    finally:
        conn.close()


@app.get("/payroll/monthly", dependencies=[Depends(require_api_key)])
def get_monthly(employeeId: int, ym: str):
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollMonthlyInput"):
            return None

        # ✅ IsDurunuri 컬럼 존재 여부 확인
        has_is_durunuri = column_exists(conn, "dbo.PayrollMonthlyInput", "IsDurunuri")

        if has_is_durunuri:
            sql = """
            SELECT EmployeeId AS employeeId, Ym AS ym, WorkHours AS workHours, Bonus AS bonus,
            OvertimeHours AS overtimeHours, NightHours AS nightHours, HolidayHours AS holidayHours,
            WeeklyHours AS weeklyHours, WeekCount AS weekCount, IsDurunuri AS isDurunuri,
            CONVERT(NVARCHAR(19), UpdatedAt, 126) AS updatedAt
            FROM dbo.PayrollMonthlyInput WHERE EmployeeId=? AND Ym=?
            """
        else:
            sql = """
            SELECT EmployeeId AS employeeId, Ym AS ym, WorkHours AS workHours, Bonus AS bonus,
            OvertimeHours AS overtimeHours, NightHours AS nightHours, HolidayHours AS holidayHours,
            WeeklyHours AS weeklyHours, WeekCount AS weekCount,
            CONVERT(NVARCHAR(19), UpdatedAt, 126) AS updatedAt
            FROM dbo.PayrollMonthlyInput WHERE EmployeeId=? AND Ym=?
            """

        row = fetch_one(conn, sql, (employeeId, ym))
        if not row:
            return None

        for k in ["workHours", "bonus", "overtimeHours", "nightHours", "holidayHours", "weeklyHours"]:
            row[k] = float(row[k] or 0)
        row["weekCount"] = int(row.get("weekCount") or 0)

        if has_is_durunuri:
            row["isDurunuri"] = bool(row.get("isDurunuri"))
        else:
            row["isDurunuri"] = False

        return row
    finally:
        conn.close()


# =========================
# 급여 계산 결과 저장 API
# =========================
@app.post("/payroll/results/save", dependencies=[Depends(require_api_key)])
def save_payroll_result(data: dict):
    """급여 계산 결과 저장 (두루누리 포함)"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollResults"):
            raise HTTPException(status_code=500, detail="dbo.PayrollResults 테이블이 없습니다.")

        # 공식 JSON 변환
        payment_formulas = json.dumps(data.get("paymentFormulas", {}), ensure_ascii=False)
        deduction_formulas = json.dumps(data.get("deductionFormulas", {}), ensure_ascii=False)

        # ✅ 두루누리 컬럼 체크
        has_duru_employer = column_exists(conn, "dbo.PayrollResults", "DuruNuriEmployerContribution")
        has_duru_employee = column_exists(conn, "dbo.PayrollResults", "DuruNuriEmployeeContribution")
        has_duru_applied = column_exists(conn, "dbo.PayrollResults", "DuruNuriApplied")

        duru_employer = float(data.get("duruNuriEmployerContribution", 0) or 0)
        duru_employee = float(data.get("duruNuriEmployeeContribution", 0) or 0)
        duru_applied = 1 if bool(data.get("duruNuriApplied", False)) else 0

        # UPDATE SET 절 구성
        update_sets = [
            "ClientId = ?",
            "BaseSalary = ?",
            "OvertimeAllowance = ?",
            "NightAllowance = ?",
            "HolidayAllowance = ?",
            "WeeklyHolidayPay = ?",
            "Bonus = ?",
            "AdditionalAllowance1Name = ?",
            "AdditionalAllowance1Amount = ?",
            "AdditionalAllowance2Name = ?",
            "AdditionalAllowance2Amount = ?",
            "TotalPayment = ?",
            "NationalPension = ?",
            "HealthInsurance = ?",
            "LongTermCare = ?",
            "EmploymentInsurance = ?",
            "IncomeTax = ?",
            "LocalIncomeTax = ?",
            "AdditionalDeduction1Name = ?",
            "AdditionalDeduction1Amount = ?",
            "AdditionalDeduction2Name = ?",
            "AdditionalDeduction2Amount = ?",
            "TotalDeduction = ?",
            "NetPay = ?",
            "PaymentFormulas = ?",
            "DeductionFormulas = ?",
            "NormalHours = ?",
            "OvertimeHours = ?",
            "NightHours = ?",
            "HolidayHours = ?",
            "AttendanceWeeks = ?",
        ]

        # INSERT 컬럼 및 VALUES
        insert_cols = [
            "EmployeeId", "ClientId", "Year", "Month",
            "BaseSalary", "OvertimeAllowance", "NightAllowance", "HolidayAllowance",
            "WeeklyHolidayPay", "Bonus",
            "AdditionalAllowance1Name", "AdditionalAllowance1Amount",
            "AdditionalAllowance2Name", "AdditionalAllowance2Amount",
            "TotalPayment",
            "NationalPension", "HealthInsurance", "LongTermCare", "EmploymentInsurance",
            "IncomeTax", "LocalIncomeTax",
            "AdditionalDeduction1Name", "AdditionalDeduction1Amount",
            "AdditionalDeduction2Name", "AdditionalDeduction2Amount",
            "TotalDeduction", "NetPay",
            "PaymentFormulas", "DeductionFormulas",
            "NormalHours", "OvertimeHours", "NightHours", "HolidayHours", "AttendanceWeeks",
        ]

        insert_vals = ["?"] * 33

        params_update = [
            data["clientId"],
            data["baseSalary"],
            data.get("overtimeAllowance", 0),
            data.get("nightAllowance", 0),
            data.get("holidayAllowance", 0),
            data.get("weeklyHolidayPay", 0),
            data.get("bonus", 0),
            data.get("additionalAllowance1Name"),
            data.get("additionalAllowance1Amount", 0),
            data.get("additionalAllowance2Name"),
            data.get("additionalAllowance2Amount", 0),
            data["totalPayment"],
            data.get("nationalPension", 0),
            data.get("healthInsurance", 0),
            data.get("longTermCare", 0),
            data.get("employmentInsurance", 0),
            data.get("incomeTax", 0),
            data.get("localIncomeTax", 0),
            data.get("additionalDeduction1Name"),
            data.get("additionalDeduction1Amount", 0),
            data.get("additionalDeduction2Name"),
            data.get("additionalDeduction2Amount", 0),
            data["totalDeduction"],
            data["netPay"],
            payment_formulas,
            deduction_formulas,
            data.get("normalHours"),
            data.get("overtimeHours"),
            data.get("nightHours"),
            data.get("holidayHours"),
            data.get("attendanceWeeks"),
        ]

        params_insert = [
            data["employeeId"], data["clientId"], data["year"], data["month"],
            data["baseSalary"],
            data.get("overtimeAllowance", 0),
            data.get("nightAllowance", 0),
            data.get("holidayAllowance", 0),
            data.get("weeklyHolidayPay", 0),
            data.get("bonus", 0),
            data.get("additionalAllowance1Name"),
            data.get("additionalAllowance1Amount", 0),
            data.get("additionalAllowance2Name"),
            data.get("additionalAllowance2Amount", 0),
            data["totalPayment"],
            data.get("nationalPension", 0),
            data.get("healthInsurance", 0),
            data.get("longTermCare", 0),
            data.get("employmentInsurance", 0),
            data.get("incomeTax", 0),
            data.get("localIncomeTax", 0),
            data.get("additionalDeduction1Name"),
            data.get("additionalDeduction1Amount", 0),
            data.get("additionalDeduction2Name"),
            data.get("additionalDeduction2Amount", 0),
            data["totalDeduction"],
            data["netPay"],
            payment_formulas,
            deduction_formulas,
            data.get("normalHours"),
            data.get("overtimeHours"),
            data.get("nightHours"),
            data.get("holidayHours"),
            data.get("attendanceWeeks"),
        ]

        # ✅ 두루누리 컬럼 추가
        if has_duru_employer:
            update_sets.append("DuruNuriEmployerContribution = ?")
            insert_cols.append("DuruNuriEmployerContribution")
            insert_vals.append("?")
            params_update.append(duru_employer)
            params_insert.append(duru_employer)

        if has_duru_employee:
            update_sets.append("DuruNuriEmployeeContribution = ?")
            insert_cols.append("DuruNuriEmployeeContribution")
            insert_vals.append("?")
            params_update.append(duru_employee)
            params_insert.append(duru_employee)

        if has_duru_applied:
            update_sets.append("DuruNuriApplied = ?")
            insert_cols.append("DuruNuriApplied")
            insert_vals.append("?")
            params_update.append(duru_applied)
            params_insert.append(duru_applied)

        update_sets.append("CalculatedAt = SYSUTCDATETIME()")
        update_sets.append("CalculatedBy = ?")
        insert_cols.append("CalculatedBy")
        insert_vals.append("?")

        params_update.append(data.get("calculatedBy", "system"))
        params_insert.append(data.get("calculatedBy", "system"))

        sql = f"""
        MERGE dbo.PayrollResults AS target
        USING (SELECT ? AS EmployeeId, ? AS Year, ? AS Month) AS source
        ON target.EmployeeId = source.EmployeeId 
            AND target.Year = source.Year 
            AND target.Month = source.Month
        WHEN MATCHED THEN
            UPDATE SET {', '.join(update_sets)}
        WHEN NOT MATCHED THEN
            INSERT ({', '.join(insert_cols)})
            VALUES ({', '.join(insert_vals)});
        """

        params = (
            data["employeeId"], data["year"], data["month"],
        ) + tuple(params_update) + tuple(params_insert)

        exec_sql(conn, sql, params)
        return {"ok": True, "employeeId": data["employeeId"], "year": data["year"], "month": data["month"]}
    finally:
        conn.close()


@app.get("/payroll/results/{employee_id}", dependencies=[Depends(require_api_key)])
def get_payroll_results(employee_id: int, year: int = Query(default=None), month: int = Query(default=None)):
    """직원 급여 이력 조회 (두루누리 포함)"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollResults"):
            return []

        # ✅ 두루누리 컬럼 체크
        has_duru_employer = column_exists(conn, "dbo.PayrollResults", "DuruNuriEmployerContribution")
        has_duru_employee = column_exists(conn, "dbo.PayrollResults", "DuruNuriEmployeeContribution")
        has_duru_applied = column_exists(conn, "dbo.PayrollResults", "DuruNuriApplied")

        select_parts = [
            "ResultId AS resultId", "EmployeeId AS employeeId", "ClientId AS clientId",
            "Year AS year", "Month AS month",
            "BaseSalary AS baseSalary", "OvertimeAllowance AS overtimeAllowance",
            "NightAllowance AS nightAllowance", "HolidayAllowance AS holidayAllowance",
            "WeeklyHolidayPay AS weeklyHolidayPay", "Bonus AS bonus",
            "AdditionalAllowance1Name AS additionalAllowance1Name",
            "AdditionalAllowance1Amount AS additionalAllowance1Amount",
            "AdditionalAllowance2Name AS additionalAllowance2Name",
            "AdditionalAllowance2Amount AS additionalAllowance2Amount",
            "TotalPayment AS totalPayment",
            "NationalPension AS nationalPension", "HealthInsurance AS healthInsurance",
            "LongTermCare AS longTermCare", "EmploymentInsurance AS employmentInsurance",
            "IncomeTax AS incomeTax", "LocalIncomeTax AS localIncomeTax",
            "AdditionalDeduction1Name AS additionalDeduction1Name",
            "AdditionalDeduction1Amount AS additionalDeduction1Amount",
            "AdditionalDeduction2Name AS additionalDeduction2Name",
            "AdditionalDeduction2Amount AS additionalDeduction2Amount",
            "TotalDeduction AS totalDeduction", "NetPay AS netPay",
            "PaymentFormulas AS paymentFormulas", "DeductionFormulas AS deductionFormulas",
            "NormalHours AS normalHours", "OvertimeHours AS overtimeHours",
            "NightHours AS nightHours", "HolidayHours AS holidayHours",
            "AttendanceWeeks AS attendanceWeeks",
        ]

        if has_duru_employer:
            select_parts.append("DuruNuriEmployerContribution AS duruNuriEmployerContribution")
        if has_duru_employee:
            select_parts.append("DuruNuriEmployeeContribution AS duruNuriEmployeeContribution")
        if has_duru_applied:
            select_parts.append("DuruNuriApplied AS duruNuriApplied")

        select_parts.append("CONVERT(NVARCHAR(19), CalculatedAt, 126) AS calculatedAt")
        select_parts.append("CalculatedBy AS calculatedBy")

        where = "WHERE EmployeeId=?"
        params = [employee_id]

        if year is not None and month is not None:
            where += " AND Year=? AND Month=?"
            params.extend([year, month])

        sql = f"SELECT {', '.join(select_parts)} FROM dbo.PayrollResults {where} ORDER BY Year DESC, Month DESC"
        rows = fetch_all(conn, sql, tuple(params))

        for r in rows:
            # 숫자 변환
            for k in ["baseSalary", "overtimeAllowance", "nightAllowance", "holidayAllowance",
                      "weeklyHolidayPay", "bonus", "additionalAllowance1Amount", "additionalAllowance2Amount",
                      "totalPayment", "nationalPension", "healthInsurance", "longTermCare",
                      "employmentInsurance", "incomeTax", "localIncomeTax",
                      "additionalDeduction1Amount", "additionalDeduction2Amount",
                      "totalDeduction", "netPay", "normalHours", "overtimeHours",
                      "nightHours", "holidayHours", "attendanceWeeks"]:
                if k in r:
                    r[k] = float(r.get(k) or 0)

            # 공식 JSON 파싱
            try:
                r["paymentFormulas"] = json.loads(r.get("paymentFormulas") or "{}")
            except:
                r["paymentFormulas"] = {}
            try:
                r["deductionFormulas"] = json.loads(r.get("deductionFormulas") or "{}")
            except:
                r["deductionFormulas"] = {}

            # 두루누리
            if has_duru_employer:
                r["duruNuriEmployerContribution"] = float(r.get("duruNuriEmployerContribution") or 0)
            else:
                r["duruNuriEmployerContribution"] = 0.0

            if has_duru_employee:
                r["duruNuriEmployeeContribution"] = float(r.get("duruNuriEmployeeContribution") or 0)
            else:
                r["duruNuriEmployeeContribution"] = 0.0

            if has_duru_applied:
                r["duruNuriApplied"] = bool(r.get("duruNuriApplied"))
            else:
                r["duruNuriApplied"] = False

        return rows
    finally:
        conn.close()


# =========================
# 급여 결과 확정 API
# =========================
@app.patch("/payroll/results/{result_id}/confirm", dependencies=[Depends(require_api_key)])
def confirm_payroll_result(result_id: int, confirmedBy: str = "admin"):
    """급여 결과 확정"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollResults"):
            raise HTTPException(status_code=500, detail="PayrollResults 테이블이 없습니다.")

        has_confirmed = column_exists(conn, "dbo.PayrollResults", "IsConfirmed")
        if not has_confirmed:
            raise HTTPException(status_code=501, detail="IsConfirmed 컬럼이 없습니다.")

        sql = """
        UPDATE dbo.PayrollResults
        SET IsConfirmed=1,
            ConfirmedAt=SYSUTCDATETIME(),
            ConfirmedBy=?
        WHERE ResultId=?
        """
        cnt = exec_sql(conn, sql, (confirmedBy, result_id))
        if cnt <= 0:
            raise HTTPException(status_code=404, detail="Result not found")

        return {"ok": True}
    finally:
        conn.close()


@app.patch("/payroll/results/{result_id}/unconfirm", dependencies=[Depends(require_api_key)])
def unconfirm_payroll_result(result_id: int):
    """급여 결과 확정 해제"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollResults"):
            raise HTTPException(status_code=500, detail="PayrollResults 테이블이 없습니다.")

        has_confirmed = column_exists(conn, "dbo.PayrollResults", "IsConfirmed")
        if not has_confirmed:
            raise HTTPException(status_code=501, detail="IsConfirmed 컬럼이 없습니다.")

        sql = """
        UPDATE dbo.PayrollResults
        SET IsConfirmed=0,
            ConfirmedAt=NULL,
            ConfirmedBy=NULL
        WHERE ResultId=?
        """
        cnt = exec_sql(conn, sql, (result_id,))
        if cnt <= 0:
            raise HTTPException(status_code=404, detail="Result not found")

        return {"ok": True}
    finally:
        conn.close()


@app.patch("/payroll/results/client/{client_id}/confirm-all", dependencies=[Depends(require_api_key)])
def confirm_all_payroll_results(client_id: int, year: int, month: int, confirmedBy: str = "admin"):
    """거래처 전체 급여 결과 일괄 확정"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollResults"):
            raise HTTPException(status_code=500, detail="PayrollResults 테이블이 없습니다.")

        has_confirmed = column_exists(conn, "dbo.PayrollResults", "IsConfirmed")
        if not has_confirmed:
            raise HTTPException(status_code=501, detail="IsConfirmed 컬럼이 없습니다.")

        sql = """
        UPDATE dbo.PayrollResults
        SET IsConfirmed=1,
            ConfirmedAt=SYSUTCDATETIME(),
            ConfirmedBy=?
        WHERE ClientId=? AND Year=? AND Month=? AND (IsConfirmed IS NULL OR IsConfirmed=0)
        """
        cnt = exec_sql(conn, sql, (confirmedBy, client_id, year, month))

        return {"ok": True, "confirmed": cnt}
    finally:
        conn.close()


@app.get("/payroll/results/client/{client_id}/confirmation-status", response_model=List[ConfirmationStatusOut], dependencies=[Depends(require_api_key)])
def get_confirmation_status(client_id: int, year: int, month: int):
    """거래처 급여 결과 확정 상태 조회"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollResults"):
            return []

        has_confirmed = column_exists(conn, "dbo.PayrollResults", "IsConfirmed")
        if not has_confirmed:
            return []

        sql = """
        SELECT 
            r.ResultId AS resultId,
            r.EmployeeId AS employeeId,
            e.Name AS employeeName,
            ISNULL(r.IsConfirmed, 0) AS isConfirmed,
            CONVERT(NVARCHAR(19), r.ConfirmedAt, 126) AS confirmedAt,
            r.ConfirmedBy AS confirmedBy
        FROM dbo.PayrollResults r
        LEFT JOIN dbo.Employees e ON r.EmployeeId = e.EmployeeId
        WHERE r.ClientId=? AND r.Year=? AND r.Month=?
        ORDER BY e.Name
        """
        rows = fetch_all(conn, sql, (client_id, year, month))

        for r in rows:
            r["isConfirmed"] = bool(r.get("isConfirmed"))

        return rows
    finally:
        conn.close()


# =========================
# SMTP 설정
# =========================
@app.get("/smtp/config", response_model=SmtpConfigOut, dependencies=[Depends(require_api_key)])
def get_smtp_config():
    """SMTP 설정 조회"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.SmtpConfig"):
            raise HTTPException(status_code=404, detail="SmtpConfig 테이블이 없습니다.")

        row = fetch_one(
            conn,
            "SELECT Host AS host, Port AS port, Username AS username, Password AS password, "
            "UseSSL AS useSSL, CONVERT(NVARCHAR(19), UpdatedAt, 126) AS updatedAt "
            "FROM dbo.SmtpConfig WHERE Id=1"
        )

        if not row:
            raise HTTPException(status_code=404, detail="SMTP 설정이 없습니다.")

        row["useSSL"] = bool(row["useSSL"])
        return row
    finally:
        conn.close()


@app.post("/smtp/config", dependencies=[Depends(require_api_key)])
def save_smtp_config(body: SmtpConfigIn):
    """SMTP 설정 저장"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.SmtpConfig"):
            raise HTTPException(status_code=500, detail="SmtpConfig 테이블이 없습니다.")

        sql = """
        MERGE dbo.SmtpConfig AS t
        USING (SELECT 1 AS Id) AS s
        ON (t.Id = s.Id)
        WHEN MATCHED THEN
            UPDATE SET Host=?, Port=?, Username=?, Password=?, UseSSL=?, UpdatedAt=SYSUTCDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (Id, Host, Port, Username, Password, UseSSL)
            VALUES (1, ?, ?, ?, ?, ?);
        """
        params = (
            body.host, body.port, body.username, body.password, int(body.useSSL),
            body.host, body.port, body.username, body.password, int(body.useSSL),
        )
        exec_sql(conn, sql, params)
        return {"ok": True}
    finally:
        conn.close()


# =========================
# 앱 설정
# =========================
@app.get("/app/settings", response_model=AppSettingsOut, dependencies=[Depends(require_api_key)])
def get_app_settings():
    """앱 설정 조회"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.AppSettings"):
            raise HTTPException(status_code=404, detail="AppSettings 테이블이 없습니다.")

        row = fetch_one(
            conn,
            "SELECT ServerUrl AS serverUrl, ApiKey AS apiKey, "
            "CONVERT(NVARCHAR(19), UpdatedAt, 126) AS updatedAt "
            "FROM dbo.AppSettings WHERE Id=1"
        )

        if not row:
            raise HTTPException(status_code=404, detail="앱 설정이 없습니다.")

        return row
    finally:
        conn.close()


@app.post("/app/settings", dependencies=[Depends(require_api_key)])
def save_app_settings(body: AppSettingsIn):
    """앱 설정 저장"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.AppSettings"):
            raise HTTPException(status_code=500, detail="AppSettings 테이블이 없습니다.")

        sql = """
        MERGE dbo.AppSettings AS t
        USING (SELECT 1 AS Id) AS s
        ON (t.Id = s.Id)
        WHEN MATCHED THEN
            UPDATE SET ServerUrl=?, ApiKey=?, UpdatedAt=SYSUTCDATETIME()
        WHEN NOT MATCHED THEN
            INSERT (Id, ServerUrl, ApiKey)
            VALUES (1, ?, ?);
        """
        params = (body.serverUrl, body.apiKey, body.serverUrl, body.apiKey)
        exec_sql(conn, sql, params)
        return {"ok": True}
    finally:
        conn.close()


# =========================
# 발송 현황
# =========================
@app.get("/clients/{client_id}/send-status", response_model=ClientSendStatusOut, dependencies=[Depends(require_api_key)])
def clients_send_status(client_id: int, ym: str, docType: Literal["slip", "register"] = "slip"):
    if not re.match(r"^\d{4}-\d{2}$", ym):
        raise HTTPException(status_code=400, detail="ym must be YYYY-MM")

    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.Employees"):
            return ClientSendStatusOut(
                clientId=client_id,
                ym=ym,
                docType=docType,
                totalTargets=0,
                sentTargets=0,
                isDone=False,
                employees=[],
            )

        if not table_exists(conn, "dbo.PayrollMailLog"):
            rows = fetch_all(
                conn,
                "SELECT EmployeeId AS employeeId, Name AS name, BirthDate AS birthDate, UseEmail AS useEmail, "
                "EmailTo AS emailTo, EmailCc AS emailCc "
                "FROM dbo.Employees WHERE ClientId=? ORDER BY Name",
                (client_id,),
            )

            employees: List[ClientSendStatusEmployeeOut] = []
            total_targets = 0

            for r in rows:
                use_email = bool(r.get("useEmail"))
                email_to = r.get("emailTo")
                email_ok = bool(email_to and str(email_to).strip() != "")
                is_target = use_email and email_ok
                if is_target:
                    total_targets += 1

                employees.append(ClientSendStatusEmployeeOut(
                    employeeId=int(r["employeeId"]),
                    name=str(r["name"] or ""),
                    birthDate=str(r["birthDate"] or ""),
                    useEmail=use_email,
                    emailTo=email_to,
                    emailCc=r.get("emailCc"),
                    lastStatus=None,
                    lastSentAt=None,
                    lastError=None,
                    isSent=False,
                ))

            return ClientSendStatusOut(
                clientId=client_id,
                ym=ym,
                docType=docType,
                totalTargets=total_targets,
                sentTargets=0,
                isDone=False,
                employees=employees,
            )

        rows = fetch_all(
            conn,
            r"""
            SELECT
                e.EmployeeId AS employeeId,
                e.Name AS name,
                e.BirthDate AS birthDate,
                e.UseEmail AS useEmail,
                e.EmailTo AS emailTo,
                e.EmailCc AS emailCc,
                ml.Status AS lastStatus,
                ml.ErrorMessage AS lastError,
                CONVERT(NVARCHAR(19), ml.SentAt, 126) AS lastSentAt
            FROM dbo.Employees e
            OUTER APPLY (
                SELECT TOP 1 Status, ErrorMessage, SentAt
                FROM dbo.PayrollMailLog m
                WHERE m.EmployeeId = e.EmployeeId
                  AND m.ClientId   = e.ClientId
                  AND m.Ym         = ?
                  AND m.DocType    = ?
                ORDER BY m.SentAt DESC, m.Id DESC
            ) ml
            WHERE e.ClientId = ?
            ORDER BY e.Name
            """,
            (ym, docType, client_id),
        )

        employees: List[ClientSendStatusEmployeeOut] = []
        total_targets = 0
        sent_targets = 0

        for r in rows:
            use_email = bool(r.get("useEmail"))
            email_to = r.get("emailTo")
            email_ok = bool(email_to and str(email_to).strip() != "")

            is_target = use_email and email_ok
            if is_target:
                total_targets += 1

            last_status = r.get("lastStatus")
            is_sent = (is_target and last_status == "sent")
            if is_sent:
                sent_targets += 1

            employees.append(ClientSendStatusEmployeeOut(
                employeeId=int(r["employeeId"]),
                name=str(r["name"] or ""),
                birthDate=str(r["birthDate"] or ""),
                useEmail=use_email,
                emailTo=email_to,
                emailCc=r.get("emailCc"),
                lastStatus=last_status,
                lastSentAt=r.get("lastSentAt"),
                lastError=r.get("lastError"),
                isSent=is_sent,
            ))

        is_done = (total_targets > 0 and sent_targets >= total_targets)

        return ClientSendStatusOut(
            clientId=client_id,
            ym=ym,
            docType=docType,
            totalTargets=total_targets,
            sentTargets=sent_targets,
            isDone=is_done,
            employees=employees,
        )

    finally:
        conn.close()


# =========================
# 파일 로그
# =========================
@app.post("/logs/doc", dependencies=[Depends(require_api_key)])
def log_doc(body: DocLogIn):
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollDocLog"):
            raise HTTPException(status_code=500, detail="dbo.PayrollDocLog 테이블이 없습니다.")

        exec_sql(
            conn,
            "INSERT INTO dbo.PayrollDocLog (ClientId, EmployeeId, Ym, DocType, FileName, FileHash, LocalPath, PcId) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (body.clientId, body.employeeId, body.ym, body.docType, body.fileName, body.fileHash, body.localPath, body.pcId),
        )
        return {"ok": True}
    finally:
        conn.close()


@app.get("/logs/doc", dependencies=[Depends(require_api_key)])
def get_doc_logs(clientId: int, ym: str):
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollDocLog"):
            return []

        rows = fetch_all(
            conn,
            "SELECT Id AS id, ClientId AS clientId, EmployeeId AS employeeId, Ym AS ym, DocType AS docType, "
            "FileName AS fileName, FileHash AS fileHash, LocalPath AS localPath, PcId AS pcId, "
            "CONVERT(NVARCHAR(19), CreatedAt, 126) AS createdAt "
            "FROM dbo.PayrollDocLog WHERE ClientId=? AND Ym=? ORDER BY Id DESC",
            (clientId, ym),
        )
        return rows
    finally:
        conn.close()


# =========================
# 메일 로그
# =========================
@app.post("/logs/mail", dependencies=[Depends(require_api_key)])
def log_mail(body: MailLogIn):
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollMailLog"):
            raise HTTPException(status_code=500, detail="dbo.PayrollMailLog 테이블이 없습니다.")

        exec_sql(
            conn,
            "INSERT INTO dbo.PayrollMailLog (ClientId, EmployeeId, Ym, DocType, ToEmail, CcEmail, Subject, Status, ErrorMessage, PcId) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (body.clientId, body.employeeId, body.ym, body.docType, body.toEmail, body.ccEmail, body.subject, body.status, body.errorMessage, body.pcId),
        )
        return {"ok": True}
    finally:
        conn.close()


@app.post("/logs/mail/bulk", dependencies=[Depends(require_api_key)])
def log_mail_bulk(body: MailLogBulkIn):
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollMailLog"):
            raise HTTPException(status_code=500, detail="dbo.PayrollMailLog 테이블이 없습니다.")

        for it in body.items:
            exec_sql(
                conn,
                "INSERT INTO dbo.PayrollMailLog (ClientId, EmployeeId, Ym, DocType, ToEmail, CcEmail, Subject, Status, ErrorMessage, PcId) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (it.clientId, it.employeeId, it.ym, it.docType, it.toEmail, it.ccEmail, it.subject, it.status, it.errorMessage, it.pcId),
            )
        return {"ok": True, "count": len(body.items)}
    finally:
        conn.close()


@app.get("/logs/mail", dependencies=[Depends(require_api_key)])
def get_mail_logs(clientId: int, ym: str, docType: Optional[str] = None):
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.PayrollMailLog"):
            return []

        if docType:
            rows = fetch_all(
                conn,
                "SELECT Id AS id, ClientId AS clientId, EmployeeId AS employeeId, Ym AS ym, DocType AS docType, "
                "ToEmail AS toEmail, CcEmail AS ccEmail, Subject AS subject, Status AS status, ErrorMessage AS errorMessage, "
                "PcId AS pcId, CONVERT(NVARCHAR(19), SentAt, 126) AS sentAt "
                "FROM dbo.PayrollMailLog WHERE ClientId=? AND Ym=? AND DocType=? ORDER BY Id DESC",
                (clientId, ym, docType),
            )
        else:
            rows = fetch_all(
                conn,
                "SELECT Id AS id, ClientId AS clientId, EmployeeId AS employeeId, Ym AS ym, DocType AS docType, "
                "ToEmail AS toEmail, CcEmail AS ccEmail, Subject AS subject, Status AS status, ErrorMessage AS errorMessage, "
                "PcId AS pcId, CONVERT(NVARCHAR(19), SentAt, 126) AS sentAt "
                "FROM dbo.PayrollMailLog WHERE ClientId=? AND Ym=? ORDER BY Id DESC",
                (clientId, ym),
            )
        return rows
    finally:
        conn.close()


# =========================
# ✅ 급여발송로그 API
# =========================
@app.post("/logs/payroll-send", dependencies=[Depends(require_api_key)])
def log_payroll_send(body: PayrollSendLogIn):
    """급여발송로그 저장 (거래처별 일괄 발송 로그)"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.급여발송로그"):
            raise HTTPException(status_code=500, detail="dbo.급여발송로그 테이블이 없습니다.")

        exec_sql(
            conn,
            """
            INSERT INTO dbo.급여발송로그 
            (거래처ID, 직원ID, 연월, 문서유형, 발송결과, 재시도횟수, 오류메시지, 수신자, 참조, 제목, 발송일시, 발송방식, 발송경로, 실행PC, 실행자)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, SYSUTCDATETIME(), ?, ?, ?, ?)
            """,
            (body.clientId, None, body.ym, body.docType, body.sendResult, body.retryCount,
             body.errorMessage, body.recipient, body.ccRecipient, body.subject,
             body.sendMethod, body.sendPath, body.executingPC, body.executor),
        )
        return {"ok": True}
    finally:
        conn.close()


@app.get("/logs/payroll-send", dependencies=[Depends(require_api_key)])
def get_payroll_send_logs(clientId: int, ym: str, docType: Optional[str] = None):
    """급여발송로그 조회"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.급여발송로그"):
            return []

        if docType:
            rows = fetch_all(
                conn,
                """
                SELECT 로그ID AS logId, 거래처ID AS clientId, 직원ID AS employeeId, 연월 AS ym, 
                문서유형 AS docType, 발송결과 AS sendResult, 재시도횟수 AS retryCount, 
                오류메시지 AS errorMessage, 수신자 AS recipient, 참조 AS ccRecipient, 제목 AS subject,
                CONVERT(NVARCHAR(19), 발송일시, 126) AS sendDate, 발송방식 AS sendMethod, 
                발송경로 AS sendPath, 실행PC AS executingPC, 실행자 AS executor
                FROM dbo.급여발송로그 
                WHERE 거래처ID=? AND 연월=? AND 문서유형=? 
                ORDER BY 로그ID DESC
                """,
                (clientId, ym, docType),
            )
        else:
            rows = fetch_all(
                conn,
                """
                SELECT 로그ID AS logId, 거래처ID AS clientId, 직원ID AS employeeId, 연월 AS ym, 
                문서유형 AS docType, 발송결과 AS sendResult, 재시도횟수 AS retryCount, 
                오류메시지 AS errorMessage, 수신자 AS recipient, 참조 AS ccRecipient, 제목 AS subject,
                CONVERT(NVARCHAR(19), 발송일시, 126) AS sendDate, 발송방식 AS sendMethod, 
                발송경로 AS sendPath, 실행PC AS executingPC, 실행자 AS executor
                FROM dbo.급여발송로그 
                WHERE 거래처ID=? AND 연월=? 
                ORDER BY 로그ID DESC
                """,
                (clientId, ym),
            )
        return rows
    finally:
        conn.close()


# =========================
# 오늘 발송대상
# =========================
@app.get("/payroll/today/clients", response_model=List[TodayClientOut], dependencies=[Depends(require_api_key)])
def payroll_today_clients(
    docType: Literal["slip", "register"] = Query(default="slip"),
):
    today = today_kst()
    ym = ym_of(today)

    conn = get_conn()
    try:
        has_5workers = column_exists(conn, "dbo.거래처", "Has5OrMoreWorkers")

        select_parts = [
            "ID AS id", "고객명 AS name", "사업자등록번호 AS bizId",
            "급여명세서발송일 AS slipSendDay", "급여대장일 AS registerSendDay",
        ]
        if has_5workers:
            select_parts.append("Has5OrMoreWorkers AS has5OrMoreWorkers")

        sql = f"SELECT {', '.join(select_parts)} FROM 거래처 WHERE 원천세='O' AND 사용여부=1"
        rows = fetch_all(conn, sql)

        out: List[TodayClientOut] = []

        import calendar
        last_day = calendar.monthrange(today.year, today.month)[1]

        for r in rows:
            cid = int(r["id"])
            name = str(r["name"] or "")
            biz = str(r["bizId"] or "")

            slip_day = safe_int(r.get("slipSendDay"))
            reg_day = safe_int(r.get("registerSendDay"))

            day = slip_day if docType == "slip" else reg_day
            if not day:
                continue

            due_raw = date(today.year, today.month, min(day, last_day))
            due = adjust_to_workday(due_raw)

            if due != today:
                continue

            total_targets = 0
            sent_targets = 0

            if table_exists(conn, "dbo.Employees"):
                target_row = fetch_one(
                    conn,
                    "SELECT COUNT(1) AS cnt "
                    "FROM dbo.Employees "
                    "WHERE ClientId=? AND UseEmail=1 AND EmailTo IS NOT NULL AND LTRIM(RTRIM(EmailTo))<>''",
                    (cid,),
                )
                total_targets = int((target_row or {}).get("cnt") or 0)

            if table_exists(conn, "dbo.PayrollMailLog"):
                sent_row = fetch_one(
                    conn,
                    "SELECT COUNT(DISTINCT EmployeeId) AS cnt "
                    "FROM dbo.PayrollMailLog "
                    "WHERE ClientId=? AND Ym=? AND DocType=? AND Status='sent' AND EmployeeId IS NOT NULL",
                    (cid, ym, docType),
                )
                sent_targets = int((sent_row or {}).get("cnt") or 0)

            is_done = (total_targets > 0 and sent_targets >= total_targets)

            out.append(TodayClientOut(
                clientId=cid,
                name=name,
                bizId=biz,
                ym=ym,
                docType=docType,
                dueDate=str(due),
                totalTargets=total_targets,
                sentTargets=sent_targets,
                isDone=is_done,
            ))

        out.sort(key=lambda x: (x.isDone, x.name))
        return out

    finally:
        conn.close()


# =========================
# 서버 SMTP 발송
# =========================
def send_email_smtp(to_email: str, subject: str, body: str, cc_email: Optional[str] = None):
    if not SMTP_HOST:
        raise RuntimeError("SMTP_HOST is not set")
    if not MAIL_FROM:
        raise RuntimeError("MAIL_FROM is not set")

    msg = EmailMessage()
    msg["From"] = MAIL_FROM
    msg["To"] = to_email
    if cc_email:
        msg["Cc"] = cc_email
    msg["Subject"] = subject
    msg.set_content(body)

    recipients = [to_email] + ([cc_email] if cc_email else [])

    if SMTP_SSL:
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, timeout=10) as s:
            if SMTP_USER:
                s.login(SMTP_USER, SMTP_PASS)
            s.send_message(msg, from_addr=MAIL_FROM, to_addrs=recipients)
    else:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as s:
            if SMTP_STARTTLS:
                s.starttls()
            if SMTP_USER:
                s.login(SMTP_USER, SMTP_PASS)
            s.send_message(msg, from_addr=MAIL_FROM, to_addrs=recipients)


@app.post("/mail/send", dependencies=[Depends(require_api_key)])
def mail_send(body: MailSendIn):
    conn = get_conn()
    try:
        try:
            send_email_smtp(body.toEmail, body.subject, body.bodyText, body.ccEmail)
            status = "sent"
            err = None
        except Exception as e:
            status = "failed"
            err = str(e)

        if table_exists(conn, "dbo.PayrollMailLog"):
            exec_sql(
                conn,
                "INSERT INTO dbo.PayrollMailLog (ClientId, EmployeeId, Ym, DocType, ToEmail, CcEmail, Subject, Status, ErrorMessage, PcId) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (body.clientId, body.employeeId, body.ym, body.docType, body.toEmail, body.ccEmail, body.subject, status, err, body.pcId),
            )

        if status == "failed":
            raise HTTPException(status_code=500, detail=f"SMTP send failed: {err}")

        return {"ok": True}
    finally:
        conn.close()


# =========================
# ✅ 거래처별 수당/공제 항목 관리 (신규)
# =========================
@app.get("/clients/{client_id}/allowance-masters", response_model=List[AllowanceMasterOut], dependencies=[Depends(require_api_key)])
def get_allowance_masters(client_id: int):
    """거래처별 수당 항목 조회"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.AllowanceMasters"):
            return []

        rows = fetch_all(
            conn,
            """
            SELECT AllowanceId AS allowanceId, ClientId AS clientId, AllowanceName AS allowanceName,
            IsActive AS isActive, CONVERT(NVARCHAR(19), CreatedAt, 126) AS createdAt
            FROM dbo.AllowanceMasters WHERE ClientId=? ORDER BY AllowanceId
            """,
            (client_id,),
        )

        for r in rows:
            r["isActive"] = bool(r.get("isActive"))

        return rows
    finally:
        conn.close()


@app.post("/clients/{client_id}/allowance-masters", dependencies=[Depends(require_api_key)])
def create_allowance_master(client_id: int, body: AllowanceMasterIn):
    """거래처별 수당 항목 생성"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.AllowanceMasters"):
            raise HTTPException(status_code=500, detail="AllowanceMasters 테이블이 없습니다.")

        exec_sql(
            conn,
            "INSERT INTO dbo.AllowanceMasters (ClientId, AllowanceName, IsActive) VALUES (?, ?, ?)",
            (client_id, body.allowanceName, int(body.isActive)),
        )
        return {"ok": True}
    finally:
        conn.close()


@app.patch("/allowance-masters/{allowance_id}", dependencies=[Depends(require_api_key)])
def update_allowance_master(allowance_id: int, body: AllowanceMasterIn):
    """수당 항목 수정"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.AllowanceMasters"):
            raise HTTPException(status_code=500, detail="AllowanceMasters 테이블이 없습니다.")

        exec_sql(
            conn,
            "UPDATE dbo.AllowanceMasters SET AllowanceName=?, IsActive=? WHERE AllowanceId=?",
            (body.allowanceName, int(body.isActive), allowance_id),
        )
        return {"ok": True}
    finally:
        conn.close()


@app.delete("/allowance-masters/{allowance_id}", dependencies=[Depends(require_api_key)])
def delete_allowance_master(allowance_id: int):
    """수당 항목 삭제"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.AllowanceMasters"):
            raise HTTPException(status_code=500, detail="AllowanceMasters 테이블이 없습니다.")

        exec_sql(conn, "DELETE FROM dbo.AllowanceMasters WHERE AllowanceId=?", (allowance_id,))
        return {"ok": True}
    finally:
        conn.close()


@app.get("/clients/{client_id}/deduction-masters", response_model=List[DeductionMasterOut], dependencies=[Depends(require_api_key)])
def get_deduction_masters(client_id: int):
    """거래처별 공제 항목 조회"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.DeductionMasters"):
            return []

        rows = fetch_all(
            conn,
            """
            SELECT DeductionId AS deductionId, ClientId AS clientId, DeductionName AS deductionName,
            IsActive AS isActive, CONVERT(NVARCHAR(19), CreatedAt, 126) AS createdAt
            FROM dbo.DeductionMasters WHERE ClientId=? ORDER BY DeductionId
            """,
            (client_id,),
        )

        for r in rows:
            r["isActive"] = bool(r.get("isActive"))

        return rows
    finally:
        conn.close()


@app.post("/clients/{client_id}/deduction-masters", dependencies=[Depends(require_api_key)])
def create_deduction_master(client_id: int, body: DeductionMasterIn):
    """거래처별 공제 항목 생성"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.DeductionMasters"):
            raise HTTPException(status_code=500, detail="DeductionMasters 테이블이 없습니다.")

        exec_sql(
            conn,
            "INSERT INTO dbo.DeductionMasters (ClientId, DeductionName, IsActive) VALUES (?, ?, ?)",
            (client_id, body.deductionName, int(body.isActive)),
        )
        return {"ok": True}
    finally:
        conn.close()


@app.patch("/deduction-masters/{deduction_id}", dependencies=[Depends(require_api_key)])
def update_deduction_master(deduction_id: int, body: DeductionMasterIn):
    """공제 항목 수정"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.DeductionMasters"):
            raise HTTPException(status_code=500, detail="DeductionMasters 테이블이 없습니다.")

        exec_sql(
            conn,
            "UPDATE dbo.DeductionMasters SET DeductionName=?, IsActive=? WHERE DeductionId=?",
            (body.deductionName, int(body.isActive), deduction_id),
        )
        return {"ok": True}
    finally:
        conn.close()


@app.delete("/deduction-masters/{deduction_id}", dependencies=[Depends(require_api_key)])
def delete_deduction_master(deduction_id: int):
    """공제 항목 삭제"""
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.DeductionMasters"):
            raise HTTPException(status_code=500, detail="DeductionMasters 테이블이 없습니다.")

        exec_sql(conn, "DELETE FROM dbo.DeductionMasters WHERE DeductionId=?", (deduction_id,))
        return {"ok": True}
    finally:
        conn.close()


# =========================
# 서버 시작
# =========================
if __name__ == "__main__":
    import uvicorn
    print(f"[BOOT] Starting Durantax Payroll API v3.0.0 on {DB_SERVER}:{DB_PORT}")
    print(f"[BOOT] Listening on http://0.0.0.0:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)
