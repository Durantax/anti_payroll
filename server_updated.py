# server.py
# FastAPI + MSSQL(pyodbc)
# - /clients : 거래처(기존 DB) 목록
# - /clients/{id}/payroll-meta : Flutter가 요구하는 거래처 급여 메타
# - /clients/{id}/send-status  : Flutter가 요구하는 발송현황(직원별)
# - dbo.Employees / dbo.PayrollMailLog는 없으면 생성 시도(INIT_DB=1)하되,
#   권한 문제로 실패해도 서버는 죽지 않게 설계

from __future__ import annotations

import os
import re
import smtplib
from email.message import EmailMessage
from datetime import datetime, date, timezone, timedelta
from typing import Optional, List, Literal, Dict, Any
from contextlib import asynccontextmanager
from typing import AsyncGenerator

import pyodbc
from fastapi import FastAPI, HTTPException, Header, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

# =========================
# 환경변수
# =========================
DB_SERVER = os.getenv("DB_SERVER", "25.2.89.129")  # 하마치 서버 IP
DB_PORT = os.getenv("DB_PORT", "1433")
DB_NAME = os.getenv("DB_NAME", "기본정보")
DB_USER = os.getenv("DB_USER", "user1")
DB_PASSWORD = os.getenv("DB_PASSWORD", "1536")

API_KEY = os.getenv("API_KEY", "")  # 비워두면 인증 생략
INIT_DB = os.getenv("INIT_DB", "1") == "1"

SMTP_HOST = os.getenv("SMTP_HOST", "")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
SMTP_STARTTLS = os.getenv("SMTP_STARTTLS", "1") == "1"
SMTP_SSL = os.getenv("SMTP_SSL", "0") == "1"
MAIL_FROM = os.getenv("MAIL_FROM", SMTP_USER)

KST = timezone(timedelta(hours=9))

# ODBC 드라이버(서버 PC에 18이 없으면 17로 바꿔야 합니다)
ODBC_DRIVER = os.getenv("ODBC_DRIVER", "ODBC Driver 18 for SQL Server")

CONN_STR = (
    f"DRIVER={{{ODBC_DRIVER}}};"
    f"SERVER={DB_SERVER},{DB_PORT};"
    f"DATABASE={DB_NAME};"
    f"UID={DB_USER};PWD={DB_PASSWORD};"
    "TrustServerCertificate=YES;"
    "Encrypt=YES;"
    "Connection Timeout=5;"
)

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

# 주말이면 "다음 월요일" 보정(기존 로직)
def adjust_to_workday_next(d: date) -> date:
    wd = d.weekday()  # Mon=0 ... Sun=6
    if wd == 5:  # Sat
        return d + timedelta(days=2)
    if wd == 6:  # Sun
        return d + timedelta(days=1)
    return d

# =========================
# DB 유틸
# =========================
def get_conn() -> pyodbc.Connection:
    return pyodbc.connect(CONN_STR)

def require_api_key(x_api_key: Optional[str] = Header(default=None, alias="X-API-Key")):
    if API_KEY:
        if not x_api_key or x_api_key != API_KEY:
            raise HTTPException(status_code=401, detail="Invalid API key")
    return True

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
    rows: List[Dict[str, Any]] = []
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

def table_exists(conn: pyodbc.Connection, full_name: str) -> bool:
    if "." in full_name:
        schema, name = full_name.split(".", 1)
    else:
        schema, name = "dbo", full_name

    row = fetch_one(
        conn,
        "SELECT 1 AS ok FROM sys.objects o "
        "JOIN sys.schemas s ON o.schema_id = s.schema_id "
        "WHERE o.type='U' AND s.name=? AND o.name=?",
        (schema, name),
    )
    return bool(row and row.get("ok") == 1)

# =========================
# 스키마(선택)
# =========================
DDL_EMPLOYEES = r"""
IF OBJECT_ID(N'dbo.Employees', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Employees (
        EmployeeId      INT IDENTITY(1,1) PRIMARY KEY,
        ClientId        INT NOT NULL,
        Name            NVARCHAR(100) NOT NULL,
        BirthDate       NVARCHAR(20) NOT NULL,
        EmploymentType  NVARCHAR(20) NOT NULL DEFAULT N'regular',
        SalaryType      NVARCHAR(20) NOT NULL DEFAULT N'HOURLY',
        BaseSalary      DECIMAL(18,2) NOT NULL DEFAULT 0,
        HourlyRate      DECIMAL(18,2) NOT NULL DEFAULT 0,
        NormalHours     DECIMAL(18,2) NOT NULL DEFAULT 209,
        FoodAllowance   DECIMAL(18,2) NOT NULL DEFAULT 0,
        CarAllowance    DECIMAL(18,2) NOT NULL DEFAULT 0,

        EmailTo         NVARCHAR(300) NULL,
        EmailCc         NVARCHAR(300) NULL,
        UseEmail        BIT NOT NULL DEFAULT 0,

        UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT UQ_Employees UNIQUE (ClientId, Name, BirthDate)
    );
END
"""

DDL_PAYROLL_MONTHLY = r"""
IF OBJECT_ID(N'dbo.PayrollMonthlyInput', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PayrollMonthlyInput (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeId      INT NOT NULL,
        Ym              NVARCHAR(7) NOT NULL,
        WorkHours       DECIMAL(18,2) NOT NULL DEFAULT 0,
        Bonus           DECIMAL(18,2) NOT NULL DEFAULT 0,
        OvertimeHours   DECIMAL(18,2) NOT NULL DEFAULT 0,
        NightHours      DECIMAL(18,2) NOT NULL DEFAULT 0,
        HolidayHours    DECIMAL(18,2) NOT NULL DEFAULT 0,
        WeeklyHours     DECIMAL(18,2) NOT NULL DEFAULT 40.0,
        WeekCount       INT NOT NULL DEFAULT 4,
        CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_PayrollMonthly UNIQUE (EmployeeId, Ym)
    );
END
"""

DDL_DOC_LOG = r"""
IF OBJECT_ID(N'dbo.PayrollDocLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PayrollDocLog (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        ClientId      INT NOT NULL,
        EmployeeId    INT NULL,
        Ym            NVARCHAR(7) NOT NULL,
        DocType       NVARCHAR(30) NOT NULL,
        FileName      NVARCHAR(260) NOT NULL,
        FileHash      NVARCHAR(64) NULL,
        LocalPath     NVARCHAR(500) NULL,
        PcId          NVARCHAR(100) NULL,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END
"""

DDL_MAIL_LOG = r"""
IF OBJECT_ID(N'dbo.PayrollMailLog', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PayrollMailLog (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        ClientId      INT NOT NULL,
        EmployeeId    INT NULL,
        Ym            NVARCHAR(7) NOT NULL,
        DocType       NVARCHAR(30) NOT NULL,
        ToEmail       NVARCHAR(300) NOT NULL,
        CcEmail       NVARCHAR(300) NULL,
        Subject       NVARCHAR(300) NOT NULL,
        Status        NVARCHAR(30) NOT NULL,
        ErrorMessage  NVARCHAR(1000) NULL,
        PcId          NVARCHAR(100) NULL,
        SentAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END
"""

# =========================
# DTO
# =========================
class ClientOut(BaseModel):
    id: int
    name: str
    bizId: str
    slipSendDay: Optional[int] = None
    registerSendDay: Optional[int] = None

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

class EmployeeOut(BaseModel):
    employeeId: int
    clientId: int
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
    updatedAt: str

class MonthlyUpsertIn(BaseModel):
    employeeId: int
    ym: str = Field(..., description="YYYY-MM format")
    workHours: float = 0
    bonus: float = 0
    overtimeHours: float = 0
    nightHours: float = 0
    holidayHours: float = 0
    weeklyHours: float = 40.0
    weekCount: int = 4

class MonthlyOut(BaseModel):
    id: int
    employeeId: int
    ym: str
    workHours: float
    bonus: float
    overtimeHours: float
    nightHours: float
    holidayHours: float
    weeklyHours: float
    weekCount: int
    createdAt: str
    updatedAt: str

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

# =========================
# Lifespan
# =========================
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    if INIT_DB:
        try:
            conn = get_conn()
            exec_sql(conn, DDL_EMPLOYEES)
            exec_sql(conn, DDL_PAYROLL_MONTHLY)
            exec_sql(conn, DDL_DOC_LOG)
            exec_sql(conn, DDL_MAIL_LOG)
            conn.close()
        except Exception as e:
            # 권한 문제여도 서버는 살아있어야 합니다.
            print("[WARN] INIT_DB failed:", e)
    yield

app = FastAPI(title="Durantax Payroll API", version="1.0.0", lifespan=lifespan)

# 요청 로그(원인 추적용)
@app.middleware("http")
async def log_requests(request, call_next):
    print(f"[REQ] {request.method} {request.url.path}?{request.url.query}")
    return await call_next(request)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", dependencies=[Depends(require_api_key)])
def health():
    try:
        conn = get_conn()
        row = fetch_one(conn, "SELECT 1 AS ok")
        conn.close()
        return {"ok": True, "db": bool(row and row.get("ok") == 1), "time": now_utc()}
    except Exception as e:
        return {"ok": False, "db": False, "error": str(e), "time": now_utc()}

@app.get("/clients", response_model=List[ClientOut], dependencies=[Depends(require_api_key)])
def get_clients():
    conn = get_conn()
    try:
        rows = fetch_all(
            conn,
            "SELECT ID AS id, 고객명 AS name, 사업자등록번호 AS bizId, "
            "급여명세서발송일 AS slipSendDay, 급여대장일 AS registerSendDay "
            "FROM 거래처 WHERE 원천세='O' AND 사용여부=1 ORDER BY 고객명"
        )
        for r in rows:
            r["slipSendDay"] = safe_int(r.get("slipSendDay"))
            r["registerSendDay"] = safe_int(r.get("registerSendDay"))
        return rows
    finally:
        conn.close()

# ✅ Flutter가 요청하는 메타 엔드포인트 (404 방지)
@app.get("/clients/{client_id}/payroll-meta", dependencies=[Depends(require_api_key)])
def get_client_payroll_meta(client_id: int, ym: str):
    if not re.match(r"^\d{4}-\d{2}$", ym):
        raise HTTPException(status_code=400, detail="ym must be YYYY-MM")

    conn = get_conn()
    try:
        row = fetch_one(
            conn,
            "SELECT ID AS id, 고객명 AS name, 사업자등록번호 AS bizId, "
            "급여명세서발송일 AS slipSendDay, 급여대장일 AS registerSendDay "
            "FROM 거래처 WHERE ID=?",
            (client_id,),
        )
        if not row:
            raise HTTPException(status_code=404, detail="Client not found")

        return {
            "clientId": int(row["id"]),
            "name": str(row.get("name") or ""),
            "bizId": str(row.get("bizId") or ""),
            "ym": ym,
            "slipSendDay": safe_int(row.get("slipSendDay")),
            "registerSendDay": safe_int(row.get("registerSendDay")),
        }
    finally:
        conn.close()

@app.get("/clients/{client_id}/employees", response_model=List[EmployeeOut], dependencies=[Depends(require_api_key)])
def get_employees(client_id: int):
    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.Employees"):
            return []

        rows = fetch_all(
            conn,
            "SELECT EmployeeId AS employeeId, ClientId AS clientId, Name AS name, BirthDate AS birthDate, "
            "EmploymentType AS employmentType, SalaryType AS salaryType, "
            "BaseSalary AS baseSalary, HourlyRate AS hourlyRate, NormalHours AS normalHours, "
            "FoodAllowance AS foodAllowance, CarAllowance AS carAllowance, "
            "EmailTo AS emailTo, EmailCc AS emailCc, UseEmail AS useEmail, "
            "CONVERT(NVARCHAR(19), UpdatedAt, 126) AS updatedAt "
            "FROM dbo.Employees WHERE ClientId=? ORDER BY Name",
            (client_id,),
        )
        for r in rows:
            for k in ["baseSalary", "hourlyRate", "normalHours", "foodAllowance", "carAllowance"]:
                r[k] = float(r[k] or 0)
            r["useEmail"] = bool(r["useEmail"])
        return rows
    finally:
        conn.close()

@app.get("/payroll/status/client", response_model=ClientSendStatusOut, dependencies=[Depends(require_api_key)])
def payroll_client_status(
    clientId: int,
    ym: str,
    docType: Literal["slip", "register"] = Query(default="slip"),
):
    if not re.match(r"^\d{4}-\d{2}$", ym):
        raise HTTPException(status_code=400, detail="ym must be YYYY-MM")

    conn = get_conn()
    try:
        if not table_exists(conn, "dbo.Employees"):
            return ClientSendStatusOut(
                clientId=clientId, ym=ym, docType=docType,
                totalTargets=0, sentTargets=0, isDone=False, employees=[]
            )

        # 메일로그가 없으면 직원만 내려주기
        if not table_exists(conn, "dbo.PayrollMailLog"):
            rows = fetch_all(
                conn,
                "SELECT EmployeeId AS employeeId, Name AS name, BirthDate AS birthDate, UseEmail AS useEmail, "
                "EmailTo AS emailTo, EmailCc AS emailCc "
                "FROM dbo.Employees WHERE ClientId=? ORDER BY Name",
                (clientId,),
            )
            employees: List[ClientSendStatusEmployeeOut] = []
            total_targets = 0
            for r in rows:
                use_email = bool(r.get("useEmail"))
                email_to = r.get("emailTo")
                is_target = use_email and bool(email_to and str(email_to).strip() != "")
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
                clientId=clientId, ym=ym, docType=docType,
                totalTargets=total_targets, sentTargets=0, isDone=False, employees=employees
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
            (ym, docType, clientId),
        )

        employees: List[ClientSendStatusEmployeeOut] = []
        total_targets = 0
        sent_targets = 0

        for r in rows:
            use_email = bool(r.get("useEmail"))
            email_to = r.get("emailTo")
            is_target = use_email and bool(email_to and str(email_to).strip() != "")
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
            clientId=clientId, ym=ym, docType=docType,
            totalTargets=total_targets, sentTargets=sent_targets,
            isDone=is_done, employees=employees
        )
    finally:
        conn.close()

# ✅ Flutter alias: /clients/{id}/send-status (404 방지)
@app.get("/clients/{client_id}/send-status", response_model=ClientSendStatusOut, dependencies=[Depends(require_api_key)])
def clients_send_status(
    client_id: int,
    ym: str,
    docType: Literal["slip", "register"] = "slip",
):
    return payroll_client_status(clientId=client_id, ym=ym, docType=docType)

# =========================
# (선택) 서버 SMTP 발송(텍스트만)
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

if __name__ == "__main__":
    import uvicorn

    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))

    print("======================================")
    print("Durantax Payroll API starting...")
    print(f"URL: http://{host}:{port}")
    print("ODBC_DRIVER =", ODBC_DRIVER)
    print("======================================")

    uvicorn.run(app, host=host, port=port, log_level="info")
