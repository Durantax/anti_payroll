"""
데이터베이스 스키마 초기화 스크립트
급여관리 프로그램에 필요한 테이블을 생성합니다.
"""
import pyodbc
import streamlit as st
from database import get_db_connection, DB_SERVER, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, ODBC_DRIVER

# 직원 테이블 생성 SQL
DDL_EMPLOYEES = """
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[Employees] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [ClientId] INT NOT NULL,
        [Name] NVARCHAR(100) NOT NULL,
        [BirthDate] NVARCHAR(20) NOT NULL,
        [EmploymentType] NVARCHAR(20) NOT NULL DEFAULT N'REGULAR',
        [SalaryType] NVARCHAR(20) NOT NULL DEFAULT N'HOURLY',
        [MonthlySalary] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [HourlyRate] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [NormalHours] DECIMAL(18,2) NOT NULL DEFAULT 209,
        [FoodAllowance] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [CarAllowance] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [HasNationalPension] BIT NOT NULL DEFAULT 1,
        [HasHealthInsurance] BIT NOT NULL DEFAULT 1,
        [HasEmploymentInsurance] BIT NOT NULL DEFAULT 1,
        [TaxDependents] INT NOT NULL DEFAULT 1,
        [ChildrenCount] INT NOT NULL DEFAULT 0,
        [IncomeTaxRate] INT NOT NULL DEFAULT 100,
        [TaxFreeMeal] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [TaxFreeCarMaintenance] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [OtherTaxFree] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [UseEmail] BIT NOT NULL DEFAULT 0,
        [EmailTo] NVARCHAR(300) NULL,
        [EmailCc] NVARCHAR(300) NULL,
        [Phone] NVARCHAR(50) NULL,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        [UpdatedAt] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [UQ_Employees_ClientId_Name_BirthDate] UNIQUE ([ClientId], [Name], [BirthDate])
    );
    
    -- 인덱스 생성
    CREATE INDEX [IX_Employees_ClientId] ON [dbo].[Employees] ([ClientId]);
    CREATE INDEX [IX_Employees_Name] ON [dbo].[Employees] ([Name]);
    
    PRINT 'Table [dbo].[Employees] created successfully.';
END
ELSE
BEGIN
    PRINT 'Table [dbo].[Employees] already exists.';
END
"""

# 월별 근로 데이터 테이블 생성 SQL
DDL_PAYROLL_MONTHLY = """
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PayrollMonthlyInput]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[PayrollMonthlyInput] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [EmployeeId] INT NOT NULL,
        [Ym] NVARCHAR(7) NOT NULL,
        [NormalHours] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [OvertimeHours] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [NightHours] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [HolidayHours] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [WeeklyHours] DECIMAL(18,2) NOT NULL DEFAULT 40.0,
        [WeekCount] INT NOT NULL DEFAULT 4,
        [Bonus] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [AdditionalPay1] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [AdditionalPay2] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [AdditionalPay3] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [AdditionalDeduct1] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [AdditionalDeduct2] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [AdditionalDeduct3] DECIMAL(18,2) NOT NULL DEFAULT 0,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        [UpdatedAt] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [UQ_PayrollMonthlyInput_EmployeeId_Ym] UNIQUE ([EmployeeId], [Ym]),
        CONSTRAINT [FK_PayrollMonthlyInput_Employees] FOREIGN KEY ([EmployeeId]) 
            REFERENCES [dbo].[Employees]([Id]) ON DELETE CASCADE
    );
    
    -- 인덱스 생성
    CREATE INDEX [IX_PayrollMonthlyInput_EmployeeId] ON [dbo].[PayrollMonthlyInput] ([EmployeeId]);
    CREATE INDEX [IX_PayrollMonthlyInput_Ym] ON [dbo].[PayrollMonthlyInput] ([Ym]);
    
    PRINT 'Table [dbo].[PayrollMonthlyInput] created successfully.';
END
ELSE
BEGIN
    PRINT 'Table [dbo].[PayrollMonthlyInput] already exists.';
END
"""

# PDF 생성 로그 테이블
DDL_PDF_LOG = """
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PayrollDocLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[PayrollDocLog] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [ClientId] INT NOT NULL,
        [EmployeeId] INT NULL,
        [Ym] NVARCHAR(7) NOT NULL,
        [DocType] NVARCHAR(30) NOT NULL,
        [FileName] NVARCHAR(260) NOT NULL,
        [FileHash] NVARCHAR(64) NULL,
        [LocalPath] NVARCHAR(500) NULL,
        [PcId] NVARCHAR(100) NULL,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
    
    CREATE INDEX [IX_PayrollDocLog_ClientId_Ym] ON [dbo].[PayrollDocLog] ([ClientId], [Ym]);
    
    PRINT 'Table [dbo].[PayrollDocLog] created successfully.';
END
ELSE
BEGIN
    PRINT 'Table [dbo].[PayrollDocLog] already exists.';
END
"""

# 이메일 발송 로그 테이블
DDL_EMAIL_LOG = """
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PayrollMailLog]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[PayrollMailLog] (
        [Id] INT IDENTITY(1,1) PRIMARY KEY,
        [ClientId] INT NOT NULL,
        [EmployeeId] INT NULL,
        [Ym] NVARCHAR(7) NOT NULL,
        [DocType] NVARCHAR(30) NOT NULL,
        [ToEmail] NVARCHAR(300) NOT NULL,
        [CcEmail] NVARCHAR(300) NULL,
        [Subject] NVARCHAR(300) NOT NULL,
        [Status] NVARCHAR(30) NOT NULL,
        [ErrorMessage] NVARCHAR(1000) NULL,
        [PcId] NVARCHAR(100) NULL,
        [SentAt] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
    
    CREATE INDEX [IX_PayrollMailLog_ClientId_Ym] ON [dbo].[PayrollMailLog] ([ClientId], [Ym]);
    
    PRINT 'Table [dbo].[PayrollMailLog] created successfully.';
END
ELSE
BEGIN
    PRINT 'Table [dbo].[PayrollMailLog] already exists.';
END
"""


def initialize_database():
    """데이터베이스 스키마 초기화"""
    try:
        conn = get_db_connection()
        if not conn:
            return False, "데이터베이스 연결 실패"
        
        cursor = conn.cursor()
        results = []
        
        # 각 테이블 생성
        tables = [
            ("Employees", DDL_EMPLOYEES),
            ("PayrollMonthlyInput", DDL_PAYROLL_MONTHLY),
            ("PayrollDocLog", DDL_PDF_LOG),
            ("PayrollMailLog", DDL_EMAIL_LOG)
        ]
        
        for table_name, ddl in tables:
            try:
                cursor.execute(ddl)
                conn.commit()
                results.append(f"✅ {table_name} 테이블 확인/생성 완료")
            except Exception as e:
                error_msg = f"❌ {table_name} 테이블 생성 실패: {str(e)}"
                results.append(error_msg)
                # 테이블 생성 실패해도 계속 진행
                conn.rollback()
        
        cursor.close()
        conn.close()
        
        return True, "\n".join(results)
        
    except Exception as e:
        return False, f"데이터베이스 초기화 실패: {str(e)}"


def check_tables_exist():
    """필요한 테이블이 존재하는지 확인"""
    required_tables = ['Employees', 'PayrollMonthlyInput', 'PayrollDocLog', 'PayrollMailLog']
    
    try:
        conn = get_db_connection()
        if not conn:
            return False, []
        
        cursor = conn.cursor()
        cursor.execute("""
            SELECT TABLE_NAME 
            FROM INFORMATION_SCHEMA.TABLES 
            WHERE TABLE_SCHEMA = 'dbo' AND TABLE_TYPE = 'BASE TABLE'
            AND TABLE_NAME IN ('Employees', 'PayrollMonthlyInput', 'PayrollDocLog', 'PayrollMailLog')
        """)
        
        existing_tables = [row[0] for row in cursor.fetchall()]
        cursor.close()
        conn.close()
        
        all_exist = all(table in existing_tables for table in required_tables)
        return all_exist, existing_tables
        
    except Exception as e:
        return False, []


if __name__ == "__main__":
    # 테스트 실행
    print(f"데이터베이스 연결 정보:")
    print(f"  서버: {DB_SERVER}:{DB_PORT}")
    print(f"  데이터베이스: {DB_NAME}")
    print(f"  사용자: {DB_USER}")
    print(f"  ODBC 드라이버: {ODBC_DRIVER}")
    print()
    
    print("테이블 존재 여부 확인 중...")
    all_exist, existing = check_tables_exist()
    
    if all_exist:
        print("✅ 모든 필요한 테이블이 이미 존재합니다.")
        print(f"   존재하는 테이블: {', '.join(existing)}")
    else:
        print(f"⚠️ 일부 테이블이 없습니다. 존재하는 테이블: {', '.join(existing) if existing else '없음'}")
        print()
        print("데이터베이스 스키마 초기화 시작...")
        success, message = initialize_database()
        print()
        print(message)
        print()
        if success:
            print("✅ 데이터베이스 초기화 완료!")
        else:
            print("❌ 데이터베이스 초기화 실패!")
