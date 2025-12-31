
-- [ADDED] 2024-12-31: Payroll Results Table
IF OBJECT_ID(N'dbo.PayrollResults', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PayrollResults (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        EmployeeId INT NOT NULL,
        ClientId INT NOT NULL,
        Year INT NOT NULL,
        Month INT NOT NULL,
        
        -- Payments
        BaseSalary DECIMAL(18,2) NOT NULL DEFAULT 0,
        OvertimeAllowance DECIMAL(18,2) NOT NULL DEFAULT 0,
        NightAllowance DECIMAL(18,2) NOT NULL DEFAULT 0,
        HolidayAllowance DECIMAL(18,2) NOT NULL DEFAULT 0,
        WeeklyHolidayPay DECIMAL(18,2) NOT NULL DEFAULT 0,
        Bonus DECIMAL(18,2) NOT NULL DEFAULT 0,
        
        AdditionalAllowance1Name NVARCHAR(100) NULL,
        AdditionalAllowance1Amount DECIMAL(18,2) NOT NULL DEFAULT 0,
        AdditionalAllowance2Name NVARCHAR(100) NULL,
        AdditionalAllowance2Amount DECIMAL(18,2) NOT NULL DEFAULT 0,
        
        TotalPayment DECIMAL(18,2) NOT NULL DEFAULT 0,
        
        -- Deductions
        NationalPension DECIMAL(18,2) NOT NULL DEFAULT 0,
        HealthInsurance DECIMAL(18,2) NOT NULL DEFAULT 0,
        LongTermCare DECIMAL(18,2) NOT NULL DEFAULT 0,
        EmploymentInsurance DECIMAL(18,2) NOT NULL DEFAULT 0,
        IncomeTax DECIMAL(18,2) NOT NULL DEFAULT 0,
        LocalIncomeTax DECIMAL(18,2) NOT NULL DEFAULT 0,
        
        AdditionalDeduction1Name NVARCHAR(100) NULL,
        AdditionalDeduction1Amount DECIMAL(18,2) NOT NULL DEFAULT 0,
        AdditionalDeduction2Name NVARCHAR(100) NULL,
        AdditionalDeduction2Amount DECIMAL(18,2) NOT NULL DEFAULT 0,
        
        TotalDeduction DECIMAL(18,2) NOT NULL DEFAULT 0,
        NetPay DECIMAL(18,2) NOT NULL DEFAULT 0,
        
        -- Calculated Stats
        NormalHours DECIMAL(18,2) NOT NULL DEFAULT 0,
        OvertimeHours DECIMAL(18,2) NOT NULL DEFAULT 0,
        NightHours DECIMAL(18,2) NOT NULL DEFAULT 0,
        HolidayHours DECIMAL(18,2) NOT NULL DEFAULT 0,
        AttendanceWeeks INT NOT NULL DEFAULT 4,
        
        -- JSON Blobs for formulas
        PaymentFormulas NVARCHAR(MAX) NULL,
        DeductionFormulas NVARCHAR(MAX) NULL,
        
        -- Durunuri
        DuruNuriEmployerContribution DECIMAL(18,2) NOT NULL DEFAULT 0,
        DuruNuriEmployeeContribution DECIMAL(18,2) NOT NULL DEFAULT 0,
        DuruNuriApplied BIT NOT NULL DEFAULT 0,

        CalculatedBy NVARCHAR(100) NULL,
        ConfirmedBy NVARCHAR(100) NULL,
        IsConfirmed BIT NULL DEFAULT 0,
        ConfirmedAt DATETIME2 NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        
        CONSTRAINT UQ_PayrollResults UNIQUE (EmployeeId, Year, Month)
    );
END

-- [ADDED] 2024-12-31: Allowance Masters
IF OBJECT_ID(N'dbo.AllowanceMasters', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AllowanceMasters (
        AllowanceId INT IDENTITY(1,1) PRIMARY KEY,
        ClientId INT NOT NULL,
        AllowanceName NVARCHAR(100) NOT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- [ADDED] 2024-12-31: Deduction Masters
IF OBJECT_ID(N'dbo.DeductionMasters', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DeductionMasters (
        DeductionId INT IDENTITY(1,1) PRIMARY KEY,
        ClientId INT NOT NULL,
        DeductionName NVARCHAR(100) NOT NULL,
        IsActive BIT NOT NULL DEFAULT 1,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- [ADDED] 2024-12-31: SMTP Config
IF OBJECT_ID(N'dbo.SmtpConfig', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SmtpConfig (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Host NVARCHAR(200) NOT NULL,
        Port INT NOT NULL DEFAULT 587,
        Username NVARCHAR(200) NULL,
        Password NVARCHAR(500) NULL,
        UseSSL BIT NOT NULL DEFAULT 0,
        SenderName NVARCHAR(100) NULL,
        SenderEmail NVARCHAR(200) NULL,
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- [ADDED] 2024-12-31: App Settings
IF OBJECT_ID(N'dbo.AppSettings', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AppSettings (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        KeyName NVARCHAR(100) NULL, -- Nullable to allow new schema rows
        ValueString NVARCHAR(MAX) NULL,
        ValueInt INT NULL,
        ValueBool BIT NULL,
        ServerUrl NVARCHAR(MAX) NULL, -- Added directly
        ApiKey NVARCHAR(MAX) NULL,    -- Added directly
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- [ADDED] 2024-12-31: Payroll Log Table (Send Log)
IF OBJECT_ID(N'dbo.급여발송로그', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.급여발송로그 (
        로그ID INT IDENTITY(1,1) PRIMARY KEY,
        거래처ID INT NOT NULL,
        직원ID INT NULL,
        연월 NVARCHAR(7) NOT NULL,
        문서유형 NVARCHAR(50) NOT NULL,
        발송결과 NVARCHAR(50) NOT NULL,
        수신자 NVARCHAR(300) NULL,
        참조 NVARCHAR(300) NULL,
        제목 NVARCHAR(300) NULL,
        오류메시지 NVARCHAR(MAX) NULL,
        재시도횟수 INT DEFAULT 0,
        발송방식 NVARCHAR(50) NULL,
        발송경로 NVARCHAR(50) NULL,
        실행PC NVARCHAR(100) NULL,
        실행자 NVARCHAR(100) NULL,
        발송일시 DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
END

-- [MIGRATION] Add columns to AppSettings if missing
IF COL_LENGTH('dbo.AppSettings', 'ServerUrl') IS NULL
BEGIN
    ALTER TABLE dbo.AppSettings ADD ServerUrl NVARCHAR(MAX) NULL;
END
IF COL_LENGTH('dbo.AppSettings', 'ApiKey') IS NULL
BEGIN
    ALTER TABLE dbo.AppSettings ADD ApiKey NVARCHAR(MAX) NULL;
END

-- [MIGRATION] Add CalculatedAt/CalculatedBy to PayrollResults if missing
IF COL_LENGTH('dbo.PayrollResults', 'CalculatedAt') IS NULL
BEGIN
    ALTER TABLE dbo.PayrollResults ADD CalculatedAt DATETIME2 NULL;
END
IF COL_LENGTH('dbo.PayrollResults', 'CalculatedBy') IS NULL
BEGIN
    ALTER TABLE dbo.PayrollResults ADD CalculatedBy NVARCHAR(100) NULL;
END
