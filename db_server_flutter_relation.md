# Database - Server - Flutter Relationship

## 1. Overview
The system consists of a generic SQL Server Database (managed via `script.sql`), a FastAPI Server (`server.py`), and a Flutter Desktop Client.

## 2. Key Entities & Data Flow

### A. Clients (거래처)
- **DB Table**: `dbo.거래처` (Legacy)
  - Columns used: `ID`, `고객명`, `사업자등록번호`, `급여명세서발송일`, `급여대장일`, `Has5OrMoreWorkers`, `EmailSubjectTemplate`, `EmailBodyTemplate`.
- **Server Endpoint**: `GET /clients`
- **Flutter Model**: `Client`
- **Flow**: Flutter fetches list -> Server queries `거래처` -> Returns JSON -> Flutter displays list.

### B. Employee (직원)
- **DB Table**: `dbo.Employees`
  - Syncs key attributes (`Name`, `BirthDate`, etc.) with `dbo.직원` via logic or direct use.
- **Server Endpoint**: `/clients/{id}/employees`, `/employees/upsert`
- **Flutter Model**: `Employee`

### C. App Settings (앱 설정)
- **DB Table**: `dbo.AppSettings`
  - Columns: `Id` (PK), `ServerUrl`, `ApiKey`, `UpdatedAt`.
- **Server Endpoint**: `GET/POST /app/settings`
- **Flutter Page**: Settings Page
- **Flow**: Flutter request -> Server `SELECT TOP 1` -> Returns settings.

### D. SMTP Config (메일 설정)
- **DB Table**: `dbo.SmtpConfig`
  - Columns: `Id` (PK), `Host`, `Port`, `Username`, `Password`, `UseSSL`, `UpdatedAt`.
- **Server Endpoint**: `GET/POST /smtp/config`
- **Flutter Page**: SMTP Settings
- **Flow**: Flutter request -> Server `SELECT TOP 1` -> Returns config.

### E. Payroll Results (급여 대장/명세서 데이터)
- **DB Table**: `dbo.PayrollResults`
  - Stores calculated payroll, tax, insurance, deductions for each employee/month.
  - Includes `PaymentFormulas`, `DeductionFormulas` (JSON).
- **Server Endpoint**: `/payroll/results/save`, `/payroll/results/{id}`
- **Flutter Page**: Payslip View / Payroll Register
- **Flow**: Flutter calculates (or Server calculates) -> Save to DB -> Load for PDF generation.

## 3. Synchronization Rules
- **Schema Source of Truth**: `script.sql`.
- **Schema Updates**: Must use `script_additions.sql` for additive changes, then merged to `script.sql`.
- **Verification**: `server.py` checks `table_exists` and `column_exists` to gracefully handle schema drift.
