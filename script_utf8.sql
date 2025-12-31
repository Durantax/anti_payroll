USE [master]
GO
/****** Object:  Database [기본정보]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE DATABASE [기본정보]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'기본정보', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\기본정보.mdf' , SIZE = 73728KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'기본정보_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\기본정보_log.ldf' , SIZE = 8192KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
 WITH CATALOG_COLLATION = DATABASE_DEFAULT, LEDGER = OFF
GO
ALTER DATABASE [기본정보] SET COMPATIBILITY_LEVEL = 160
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [기본정보].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [기본정보] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [기본정보] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [기본정보] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [기본정보] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [기본정보] SET ARITHABORT OFF 
GO
ALTER DATABASE [기본정보] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [기본정보] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [기본정보] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [기본정보] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [기본정보] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [기본정보] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [기본정보] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [기본정보] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [기본정보] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [기본정보] SET  DISABLE_BROKER 
GO
ALTER DATABASE [기본정보] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [기본정보] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [기본정보] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [기본정보] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [기본정보] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [기본정보] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [기본정보] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [기본정보] SET RECOVERY SIMPLE 
GO
ALTER DATABASE [기본정보] SET  MULTI_USER 
GO
ALTER DATABASE [기본정보] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [기본정보] SET DB_CHAINING OFF 
GO
ALTER DATABASE [기본정보] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [기본정보] SET TARGET_RECOVERY_TIME = 60 SECONDS 
GO
ALTER DATABASE [기본정보] SET DELAYED_DURABILITY = DISABLED 
GO
ALTER DATABASE [기본정보] SET ACCELERATED_DATABASE_RECOVERY = OFF  
GO
ALTER DATABASE [기본정보] SET QUERY_STORE = ON
GO
ALTER DATABASE [기본정보] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), DATA_FLUSH_INTERVAL_SECONDS = 900, INTERVAL_LENGTH_MINUTES = 60, MAX_STORAGE_SIZE_MB = 1000, QUERY_CAPTURE_MODE = AUTO, SIZE_BASED_CLEANUP_MODE = AUTO, MAX_PLANS_PER_QUERY = 200, WAIT_STATS_CAPTURE_MODE = ON)
GO
USE [기본정보]
GO
/****** Object:  User [user1]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE USER [user1] FOR LOGIN [user1] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_owner] ADD MEMBER [user1]
GO
/****** Object:  FullTextCatalog [FTC_Chat]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE FULLTEXT CATALOG [FTC_Chat] 
GO
/****** Object:  Table [dbo].[채팅메시지]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[채팅메시지](
	[메시지ID] [int] IDENTITY(1,1) NOT NULL,
	[보낸이] [nvarchar](50) NOT NULL,
	[받는이] [nvarchar](50) NOT NULL,
	[본문] [nvarchar](max) NULL,
	[파일ID] [int] NULL,
	[보낸시각] [datetime2](3) NOT NULL,
	[읽은시각] [datetime2](3) NULL,
	[대화키]  AS (case when [보낸이]<=[받는이] then ([보낸이]+N'|')+[받는이] else ([받는이]+N'|')+[보낸이] end) PERSISTED NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[메시지ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[vw_채팅_미열람수]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vw_채팅_미열람수] AS
SELECT 받는이, 보낸이, COUNT(*) AS 미열람수
FROM dbo.채팅메시지
WHERE 읽은시각 IS NULL
GROUP BY 받는이, 보낸이;
GO
/****** Object:  Table [dbo].[채팅파일]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[채팅파일](
	[파일ID] [int] IDENTITY(1,1) NOT NULL,
	[원본파일명] [nvarchar](255) NOT NULL,
	[콘텐츠] [varbinary](max) NULL,
	[MIME] [nvarchar](100) NOT NULL,
	[크기] [bigint] NOT NULL,
	[업로더] [nvarchar](50) NOT NULL,
	[업로드시각] [datetime2](3) NOT NULL,
	[파일경로] [nvarchar](4000) NULL,
	[저장방식] [nchar](2) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[파일ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[vw_채팅_이미지목록]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vw_채팅_이미지목록] AS
SELECT m.메시지ID, m.보낸이, m.받는이, f.파일ID, f.원본파일명, m.보낸시각
FROM dbo.채팅메시지 m
JOIN dbo.채팅파일 f ON f.파일ID = m.파일ID
WHERE f.MIME LIKE N'image/%';
GO
/****** Object:  Table [dbo].[PayrollStatement]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PayrollStatement](
	[StatementId] [int] IDENTITY(1,1) NOT NULL,
	[EmployeeId] [int] NOT NULL,
	[ClientId] [int] NOT NULL,
	[Year] [int] NOT NULL,
	[Month] [int] NOT NULL,
	[TotalEarnings] [decimal](18, 2) NOT NULL,
	[TotalDeductions] [decimal](18, 2) NOT NULL,
	[NetPay] [decimal](18, 2) NOT NULL,
	[IsFinalized] [bit] NOT NULL,
	[FinalizedAt] [datetime2](7) NULL,
	[FinalizedBy] [nvarchar](100) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[StatementId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[EmployeeId] ASC,
	[Year] ASC,
	[Month] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PayrollStatementModification]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PayrollStatementModification](
	[ModificationId] [int] IDENTITY(1,1) NOT NULL,
	[StatementId] [int] NOT NULL,
	[DetailId] [int] NULL,
	[ItemName] [nvarchar](100) NOT NULL,
	[OriginalAmount] [decimal](18, 2) NOT NULL,
	[ModifiedAmount] [decimal](18, 2) NOT NULL,
	[ModificationReason] [nvarchar](500) NULL,
	[ModifiedAt] [datetime2](7) NOT NULL,
	[ModifiedBy] [nvarchar](100) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ModificationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Employees]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Employees](
	[EmployeeId] [int] IDENTITY(1,1) NOT NULL,
	[ClientId] [int] NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[BirthDate] [nvarchar](20) NOT NULL,
	[EmploymentType] [nvarchar](20) NOT NULL,
	[SalaryType] [nvarchar](20) NOT NULL,
	[BaseSalary] [decimal](18, 2) NOT NULL,
	[HourlyRate] [decimal](18, 2) NOT NULL,
	[NormalHours] [decimal](18, 2) NOT NULL,
	[FoodAllowance] [decimal](18, 2) NOT NULL,
	[CarAllowance] [decimal](18, 2) NOT NULL,
	[EmailTo] [nvarchar](300) NULL,
	[EmailCc] [nvarchar](300) NULL,
	[UseEmail] [bit] NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
	[HasNationalPension] [bit] NOT NULL,
	[HasHealthInsurance] [bit] NOT NULL,
	[HasEmploymentInsurance] [bit] NOT NULL,
	[HealthInsuranceBasis] [nvarchar](20) NOT NULL,
	[PensionInsurableWage] [decimal](18, 2) NULL,
	[TaxDependents] [int] NOT NULL,
	[ChildrenCount] [int] NOT NULL,
	[TaxFreeMeal] [decimal](18, 2) NOT NULL,
	[TaxFreeCarMaintenance] [decimal](18, 2) NOT NULL,
	[OtherTaxFree] [decimal](18, 2) NOT NULL,
	[IncomeTaxRate] [int] NOT NULL,
	[JoinDate] [date] NULL,
	[ResignDate] [date] NULL,
	[EmpNo] [char](4) NULL,
	[EmployeeNumber] [nvarchar](50) NULL,
	[BankName] [nvarchar](50) NULL,
	[BankAccount] [nvarchar](50) NULL,
	[BankOwner] [nvarchar](50) NULL,
	[Memo] [nvarchar](max) NULL,
	[HireDate] [nvarchar](10) NULL,
	[TerminationDate] [nvarchar](10) NULL,
PRIMARY KEY CLUSTERED 
(
	[EmployeeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Employees] UNIQUE NONCLUSTERED 
(
	[ClientId] ASC,
	[Name] ASC,
	[BirthDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[거래처]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[거래처](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[고객명] [nvarchar](100) NOT NULL,
	[계약일] [date] NULL,
	[담당자] [nvarchar](50) NULL,
	[사업자등록번호] [nvarchar](50) NULL,
	[이메일] [nvarchar](100) NULL,
	[연락처] [nvarchar](50) NULL,
	[홈택스_ID] [nvarchar](50) NULL,
	[홈택스_PW] [nvarchar](50) NULL,
	[사업자] [nvarchar](50) NULL,
	[기장결제일] [int] NULL,
	[기장여부] [nvarchar](50) NULL,
	[원천세] [nvarchar](50) NULL,
	[급여명세서발송일] [int] NULL,
	[급여대장일] [int] NULL,
	[급여비고] [nvarchar](50) NULL,
	[위하고_ID] [nvarchar](50) NULL,
	[위하고_PW] [nvarchar](50) NULL,
	[사용여부] [nvarchar](50) NULL,
	[대표자] [nvarchar](50) NULL,
	[Has5OrMoreWorkers] [bit] NOT NULL,
	[EmailSubjectTemplate] [nvarchar](500) NOT NULL,
	[EmailBodyTemplate] [nvarchar](2000) NOT NULL,
	[발송설정] [nvarchar](10) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[vw_PayrollStatement_Summary]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[vw_PayrollStatement_Summary] AS
SELECT 
    ps.StatementId,
    ps.Year,
    ps.Month,
    CONCAT(ps.Year, '-', FORMAT(ps.Month, '00')) AS YearMonth,
    e.EmployeeId,
    e.Name AS EmployeeName,
    c.고객명 AS ClientName,
    ps.TotalEarnings,
    ps.TotalDeductions,
    ps.NetPay,
    ps.IsFinalized,
    ps.FinalizedAt,
    ps.FinalizedBy,
    ps.CreatedAt,
    ps.UpdatedAt,
    (SELECT COUNT(*) FROM dbo.PayrollStatementModification WHERE StatementId = ps.StatementId) AS ModificationCount
FROM dbo.PayrollStatement ps
INNER JOIN dbo.Employees e ON ps.EmployeeId = e.EmployeeId
INNER JOIN dbo.거래처 c ON ps.ClientId = c.ID;
GO
/****** Object:  Table [dbo].[PayrollResults]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PayrollResults](
	[ResultId] [int] IDENTITY(1,1) NOT NULL,
	[EmployeeId] [int] NOT NULL,
	[ClientId] [int] NOT NULL,
	[Year] [int] NOT NULL,
	[Month] [int] NOT NULL,
	[BaseSalary] [decimal](18, 2) NOT NULL,
	[OvertimeAllowance] [decimal](18, 2) NOT NULL,
	[NightAllowance] [decimal](18, 2) NOT NULL,
	[HolidayAllowance] [decimal](18, 2) NOT NULL,
	[WeeklyHolidayPay] [decimal](18, 2) NOT NULL,
	[Bonus] [decimal](18, 2) NOT NULL,
	[AdditionalAllowance1Name] [nvarchar](100) NULL,
	[AdditionalAllowance1Amount] [decimal](18, 2) NOT NULL,
	[AdditionalAllowance2Name] [nvarchar](100) NULL,
	[AdditionalAllowance2Amount] [decimal](18, 2) NOT NULL,
	[TotalPayment] [decimal](18, 2) NOT NULL,
	[NationalPension] [decimal](18, 2) NOT NULL,
	[HealthInsurance] [decimal](18, 2) NOT NULL,
	[LongTermCare] [decimal](18, 2) NOT NULL,
	[EmploymentInsurance] [decimal](18, 2) NOT NULL,
	[IncomeTax] [decimal](18, 2) NOT NULL,
	[LocalIncomeTax] [decimal](18, 2) NOT NULL,
	[AdditionalDeduction1Name] [nvarchar](100) NULL,
	[AdditionalDeduction1Amount] [decimal](18, 2) NOT NULL,
	[AdditionalDeduction2Name] [nvarchar](100) NULL,
	[AdditionalDeduction2Amount] [decimal](18, 2) NOT NULL,
	[TotalDeduction] [decimal](18, 2) NOT NULL,
	[NetPay] [decimal](18, 2) NOT NULL,
	[PaymentFormulas] [nvarchar](max) NULL,
	[DeductionFormulas] [nvarchar](max) NULL,
	[NormalHours] [decimal](10, 2) NULL,
	[OvertimeHours] [decimal](10, 2) NULL,
	[NightHours] [decimal](10, 2) NULL,
	[HolidayHours] [decimal](10, 2) NULL,
	[AttendanceWeeks] [int] NULL,
	[CalculatedAt] [datetime2](7) NOT NULL,
	[CalculatedBy] [nvarchar](100) NULL,
	[IsPdfGenerated] [bit] NOT NULL,
	[IsEmailSent] [bit] NOT NULL,
	[PdfGeneratedAt] [datetime2](7) NULL,
	[EmailSentAt] [datetime2](7) NULL,
	[IsConfirmed] [bit] NOT NULL,
	[ConfirmedAt] [datetime2](7) NULL,
	[ConfirmedBy] [nvarchar](100) NULL,
	[YearEndAdjustmentAmount] [decimal](18, 2) NOT NULL,
	[HealthInsurancePremiumAdjustment] [decimal](18, 2) NOT NULL,
	[DuruNuriEmployerContribution] [decimal](18, 2) NOT NULL,
	[DuruNuriEmployeeContribution] [decimal](18, 2) NOT NULL,
	[DuruNuriApplied] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ResultId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_PayrollResults_Unique] UNIQUE NONCLUSTERED 
(
	[EmployeeId] ASC,
	[Year] ASC,
	[Month] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[vw_PayrollHistory]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- 뷰 생성 (급여 이력 조회용)
CREATE VIEW [dbo].[vw_PayrollHistory] AS
SELECT 
    pr.ResultId,
    pr.Year,
    pr.Month,
    c.고객명 AS ClientName,  -- ✅ 고객명으로 수정
    e.Name AS EmployeeName,
    e.Birthdate,
    e.EmploymentType,
    pr.TotalPayment,
    pr.TotalDeduction,
    pr.NetPay,
    pr.CalculatedAt,
    pr.IsPdfGenerated,
    pr.IsEmailSent,
    pr.EmailSentAt
FROM dbo.PayrollResults pr
INNER JOIN dbo.Employees e ON pr.EmployeeId = e.EmployeeId
INNER JOIN dbo.거래처 c ON pr.ClientId = c.ID;  -- ✅ ID로 수정
GO
/****** Object:  Table [dbo].[일정]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[일정](
	[일정ID] [int] IDENTITY(1,1) NOT NULL,
	[납세자ID] [int] NULL,
	[거래처ID] [int] NULL,
	[카테고리] [nvarchar](30) NOT NULL,
	[기준일] [date] NOT NULL,
	[신고기한] [date] NOT NULL,
	[설명] [nvarchar](200) NULL,
	[중요] [bit] NULL,
	[상태] [nvarchar](6) NULL,
	[제목] [nvarchar](200) NULL,
	[시작일시] [datetime2](0) NULL,
	[종료일시] [datetime2](0) NULL,
	[종일] [bit] NOT NULL,
	[알림분전] [int] NULL,
	[반복규칙] [nvarchar](255) NULL,
	[반복종료일] [date] NULL,
	[출처] [nvarchar](20) NOT NULL,
	[참조구분] [nvarchar](30) NULL,
	[참조ID] [int] NULL,
	[사건구분] [nvarchar](10) NULL,
	[사건ID] [int] NULL,
	[완료일시] [datetime2](0) NULL,
	[위치] [nvarchar](200) NULL,
	[메모] [nvarchar](max) NULL,
	[생성일시] [datetime2](0) NOT NULL,
	[수정일시] [datetime2](0) NOT NULL,
	[표시일자]  AS (CONVERT([date],coalesce([시작일시],[기준일],[신고기한]))) PERSISTED,
PRIMARY KEY CLUSTERED 
(
	[일정ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo].[vw_알림목록_발송설정포함]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   VIEW [dbo].[vw_알림목록_발송설정포함] AS
SELECT 
    S.일정ID,
    S.제목,
    S.설명,
    C.고객명,
    C.발송설정, -- [매크로, 급여, 둘다, 사용안함] 정보 가져오기
    S.참조구분, -- SEND_MACRO 또는 SEND_PAYROLL
    S.상태,
    S.참조ID AS [연월ID],
    S.표시일자
FROM dbo.일정 S
JOIN dbo.거래처 C ON S.거래처ID = C.ID
WHERE S.상태 <> N'완료' 
  AND S.참조구분 IN ('SEND_MACRO', 'SEND_PAYROLL');
GO
/****** Object:  Table [dbo].[납세자]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[납세자](
	[납세자ID] [int] IDENTITY(1,1) NOT NULL,
	[성명] [nvarchar](40) NOT NULL,
	[주민등록번호] [char](13) NOT NULL,
	[연락처] [nvarchar](20) NULL,
	[주소] [nvarchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[납세자ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[주민등록번호] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[상속증여사건]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[상속증여사건](
	[사건ID] [int] IDENTITY(1,1) NOT NULL,
	[납세자ID] [int] NOT NULL,
	[사건구분] [nvarchar](2) NOT NULL,
	[사건일자] [date] NOT NULL,
	[신고기한] [date] NOT NULL,
	[상태] [nvarchar](6) NULL,
	[설명] [nvarchar](200) NULL,
PRIMARY KEY CLUSTERED 
(
	[사건ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[양도신고서]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[양도신고서](
	[신고서ID] [int] IDENTITY(1,1) NOT NULL,
	[납세자ID] [int] NOT NULL,
	[신고구분] [nvarchar](20) NOT NULL,
	[기간시작] [date] NOT NULL,
	[기간종료] [date] NOT NULL,
	[신고기한] [date] NOT NULL,
	[상태] [nvarchar](6) NULL,
PRIMARY KEY CLUSTERED 
(
	[신고서ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[현금영수증]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[현금영수증](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[납세자ID] [int] NOT NULL,
	[사건구분] [nvarchar](10) NOT NULL,
	[사건ID] [int] NOT NULL,
	[등록일] [date] NOT NULL,
	[완료] [bit] NOT NULL,
	[완료일시] [datetime2](0) NULL,
	[비고] [nvarchar](200) NULL,
 CONSTRAINT [PK_현금영수증] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_현금영수증] UNIQUE NONCLUSTERED 
(
	[사건구분] ASC,
	[사건ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo].[vw_현금영수증_목록]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vw_현금영수증_목록]
AS
SELECT
    y.ID,
    COALESCE(sz.납세자ID, yg.납세자ID, y.납세자ID) AS 납세자ID,
    n.성명 AS 납세자,
    y.사건구분,
    CASE WHEN y.사건구분 IN (N'상속', N'증여') THEN sz.사건일자 ELSE yg.기간시작 END AS 사건일자,
    CASE WHEN y.사건구분 IN (N'상속', N'증여') THEN sz.신고기한 ELSE yg.신고기한 END AS 신고기한,
    y.등록일,
    y.완료,
    y.완료일시,
    y.비고
FROM dbo.현금영수증 y
LEFT JOIN dbo.상속증여사건 sz
       ON y.사건구분 IN (N'상속', N'증여') AND y.사건ID = sz.사건ID
LEFT JOIN dbo.양도신고서 yg
       ON y.사건구분 = N'양도' AND y.사건ID = yg.신고서ID
LEFT JOIN dbo.납세자 n
       ON n.납세자ID = COALESCE(sz.납세자ID, yg.납세자ID, y.납세자ID);
GO
/****** Object:  Table [dbo].[AllowanceMaster]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AllowanceMaster](
	[AllowanceId] [int] IDENTITY(1,1) NOT NULL,
	[ClientId] [int] NOT NULL,
	[AllowanceName] [nvarchar](100) NOT NULL,
	[AllowanceCode] [nvarchar](50) NULL,
	[IsTaxable] [bit] NOT NULL,
	[IsMonthlyDefault] [bit] NOT NULL,
	[DefaultAmount] [decimal](18, 2) NOT NULL,
	[Description] [nvarchar](500) NULL,
	[DisplayOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[AllowanceId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_AllowanceMaster_ClientName] UNIQUE NONCLUSTERED 
(
	[ClientId] ASC,
	[AllowanceName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[AppSettings]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AppSettings](
	[Id] [int] NOT NULL,
	[ServerUrl] [nvarchar](500) NOT NULL,
	[ApiKey] [nvarchar](200) NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[DeductionMaster]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DeductionMaster](
	[DeductionId] [int] IDENTITY(1,1) NOT NULL,
	[ClientId] [int] NOT NULL,
	[DeductionName] [nvarchar](100) NOT NULL,
	[DeductionCode] [nvarchar](50) NULL,
	[DeductionType] [nvarchar](20) NOT NULL,
	[IsPreTax] [bit] NOT NULL,
	[IsMonthlyDefault] [bit] NOT NULL,
	[DefaultAmount] [decimal](18, 2) NOT NULL,
	[Description] [nvarchar](500) NULL,
	[DisplayOrder] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[DeductionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_DeductionMaster_ClientName] UNIQUE NONCLUSTERED 
(
	[ClientId] ASC,
	[DeductionName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EmployeeAllowances]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmployeeAllowances](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EmployeeId] [int] NOT NULL,
	[AllowanceId] [int] NOT NULL,
	[Amount] [decimal](18, 2) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[StartDate] [date] NULL,
	[EndDate] [date] NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_EmployeeAllowances] UNIQUE NONCLUSTERED 
(
	[EmployeeId] ASC,
	[AllowanceId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EmployeeDeductions]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmployeeDeductions](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EmployeeId] [int] NOT NULL,
	[DeductionId] [int] NOT NULL,
	[Amount] [decimal](18, 2) NOT NULL,
	[IsActive] [bit] NOT NULL,
	[StartDate] [date] NULL,
	[EndDate] [date] NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_EmployeeDeductions] UNIQUE NONCLUSTERED 
(
	[EmployeeId] ASC,
	[DeductionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EmployeeNoCounter]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmployeeNoCounter](
	[ClientId] [int] NOT NULL,
	[NextNo] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ClientId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[EmployeePayrollItems]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmployeePayrollItems](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EmployeeId] [int] NOT NULL,
	[ItemId] [int] NOT NULL,
	[IsEnabled] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_EmployeeItems] UNIQUE NONCLUSTERED 
(
	[EmployeeId] ASC,
	[ItemId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PayrollDocLog]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PayrollDocLog](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ClientId] [int] NOT NULL,
	[EmployeeId] [int] NULL,
	[Ym] [nvarchar](7) NOT NULL,
	[DocType] [nvarchar](30) NOT NULL,
	[FileName] [nvarchar](260) NOT NULL,
	[FileHash] [nvarchar](64) NULL,
	[LocalPath] [nvarchar](500) NULL,
	[PcId] [nvarchar](100) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PayrollItemTemplate]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PayrollItemTemplate](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ItemName] [nvarchar](100) NOT NULL,
	[ItemType] [nvarchar](20) NOT NULL,
	[DefaultAmount] [decimal](18, 2) NULL,
	[IsActive] [bit] NOT NULL,
	[DisplayOrder] [int] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PayrollMailLog]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PayrollMailLog](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ClientId] [int] NOT NULL,
	[EmployeeId] [int] NULL,
	[Ym] [nvarchar](7) NOT NULL,
	[DocType] [nvarchar](30) NOT NULL,
	[ToEmail] [nvarchar](300) NOT NULL,
	[CcEmail] [nvarchar](300) NULL,
	[Subject] [nvarchar](300) NOT NULL,
	[Status] [nvarchar](30) NOT NULL,
	[ErrorMessage] [nvarchar](1000) NULL,
	[PcId] [nvarchar](100) NULL,
	[SentAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PayrollMonthlyAdjustments]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PayrollMonthlyAdjustments](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EmployeeId] [int] NOT NULL,
	[Ym] [nvarchar](7) NOT NULL,
	[Type] [nvarchar](20) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Amount] [decimal](18, 2) NOT NULL,
	[IsTaxable] [bit] NULL,
	[IsPreTax] [bit] NULL,
	[Reason] [nvarchar](500) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[CreatedBy] [nvarchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PayrollMonthlyInput]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PayrollMonthlyInput](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EmployeeId] [int] NOT NULL,
	[Ym] [nvarchar](7) NOT NULL,
	[WorkHours] [decimal](18, 2) NOT NULL,
	[Bonus] [decimal](18, 2) NOT NULL,
	[OvertimeHours] [decimal](18, 2) NOT NULL,
	[NightHours] [decimal](18, 2) NOT NULL,
	[HolidayHours] [decimal](18, 2) NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
	[ExtraAllowance] [decimal](18, 2) NOT NULL,
	[ExtraDeduction] [decimal](18, 2) NOT NULL,
	[Memo] [nvarchar](500) NULL,
	[WeeklyHours] [decimal](18, 2) NOT NULL,
	[WeekCount] [int] NOT NULL,
	[IsDurunuri] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_PayrollMonthly] UNIQUE NONCLUSTERED 
(
	[EmployeeId] ASC,
	[Ym] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PayrollMonthlyItems]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PayrollMonthlyItems](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[EmployeeId] [int] NOT NULL,
	[Ym] [nvarchar](7) NOT NULL,
	[ItemId] [int] NOT NULL,
	[Amount] [decimal](18, 2) NOT NULL,
	[Memo] [nvarchar](200) NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_MonthlyItems] UNIQUE NONCLUSTERED 
(
	[EmployeeId] ASC,
	[Ym] ASC,
	[ItemId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[PayrollStatementDetail]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PayrollStatementDetail](
	[DetailId] [int] IDENTITY(1,1) NOT NULL,
	[StatementId] [int] NOT NULL,
	[ItemName] [nvarchar](100) NOT NULL,
	[ItemType] [nvarchar](20) NOT NULL,
	[ItemCode] [nvarchar](50) NULL,
	[Amount] [decimal](18, 2) NOT NULL,
	[DisplayOrder] [int] NOT NULL,
	[Memo] [nvarchar](200) NULL,
	[IsDeleted] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[DetailId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[SmtpConfig]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SmtpConfig](
	[Id] [int] NOT NULL,
	[Host] [nvarchar](200) NOT NULL,
	[Port] [int] NOT NULL,
	[Username] [nvarchar](200) NOT NULL,
	[Password] [nvarchar](500) NOT NULL,
	[UseSSL] [bit] NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[급여발송로그]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[급여발송로그](
	[로그ID] [int] IDENTITY(1,1) NOT NULL,
	[거래처ID] [int] NOT NULL,
	[직원ID] [int] NULL,
	[연월] [nvarchar](7) NOT NULL,
	[문서유형] [nvarchar](30) NOT NULL,
	[발송결과] [nvarchar](20) NOT NULL,
	[재시도횟수] [int] NOT NULL,
	[오류메시지] [nvarchar](1000) NULL,
	[수신자] [nvarchar](300) NULL,
	[참조] [nvarchar](300) NULL,
	[제목] [nvarchar](300) NULL,
	[발송일시] [datetime2](3) NOT NULL,
	[발송방식] [nvarchar](20) NOT NULL,
	[발송경로] [nvarchar](20) NOT NULL,
	[실행PC] [nvarchar](100) NULL,
	[실행자] [nvarchar](50) NULL,
PRIMARY KEY CLUSTERED 
(
	[로그ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[담당자]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[담당자](
	[담당자ID] [int] IDENTITY(1,1) NOT NULL,
	[이름] [nvarchar](50) NOT NULL,
	[연락처] [nvarchar](50) NULL,
	[이메일] [nvarchar](100) NULL,
	[SMTP_HOST] [nvarchar](100) NULL,
	[SMTP_PORT] [int] NULL,
	[SMTP_USER] [nvarchar](100) NULL,
	[SMTP_PASS] [nvarchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[담당자ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_담당자_이름] UNIQUE NONCLUSTERED 
(
	[이름] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[발송로그]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[발송로그](
	[로그ID] [int] IDENTITY(1,1) NOT NULL,
	[회사ID] [varchar](50) NOT NULL,
	[회사명] [varchar](100) NOT NULL,
	[발송유형] [varchar](20) NOT NULL,
	[발송결과] [varchar](20) NOT NULL,
	[재시도횟수] [int] NOT NULL,
	[오류메시지] [varchar](4000) NULL,
	[발송일시] [datetime] NOT NULL,
	[담당자] [varchar](50) NULL,
	[발송방법] [nvarchar](10) NULL,
PRIMARY KEY CLUSTERED 
(
	[로그ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[상담로그]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[상담로그](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[회사ID] [int] NOT NULL,
	[상담일] [date] NOT NULL,
	[작성일시] [datetime] NOT NULL,
	[내용] [nvarchar](max) NOT NULL,
	[중요] [bit] NOT NULL,
	[납세자ID] [int] NULL,
	[자산ID] [int] NULL,
	[사건ID] [int] NULL,
	[신고서ID] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[신고자산연결]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[신고자산연결](
	[신고서ID] [int] NOT NULL,
	[자산ID] [int] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[신고서ID] ASC,
	[자산ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[알림로그]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[알림로그](
	[로그ID] [int] IDENTITY(1,1) NOT NULL,
	[알림ID] [int] NOT NULL,
	[발송일시] [datetime2](0) NOT NULL,
	[결과] [nvarchar](50) NULL,
	[메시지] [nvarchar](400) NULL,
PRIMARY KEY CLUSTERED 
(
	[로그ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[양도자산]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[양도자산](
	[자산ID] [int] IDENTITY(1,1) NOT NULL,
	[납세자ID] [int] NOT NULL,
	[자산종류] [nvarchar](20) NULL,
	[양도일자] [date] NOT NULL,
	[취득가액] [money] NULL,
	[양도가액] [money] NULL,
	[메모] [nvarchar](200) NULL,
PRIMARY KEY CLUSTERED 
(
	[자산ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[원천세관리]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[원천세관리](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[회사ID] [int] NOT NULL,
	[연도] [int] NOT NULL,
	[월] [int] NOT NULL,
	[상태] [nvarchar](10) NOT NULL,
	[카카오발송] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_원천세관리] UNIQUE NONCLUSTERED 
(
	[회사ID] ASC,
	[연도] ASC,
	[월] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[원천세업무]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[원천세업무](
	[회사ID] [int] NOT NULL,
	[홈택스등록] [bit] NOT NULL,
	[두란DB업로드] [bit] NOT NULL,
	[세무사랑업로드] [bit] NOT NULL,
	[CMS등록] [bit] NOT NULL,
	[국민연금사업장] [bit] NOT NULL,
	[건강보험사업장] [bit] NOT NULL,
	[고용산재사업장] [bit] NOT NULL,
	[자격취득신고] [bit] NOT NULL,
	[건강보험EDI] [bit] NOT NULL,
	[국민연금EDI] [bit] NOT NULL,
	[사대보험미가입] [bit] NOT NULL,
	[수정일시] [datetime2](0) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[회사ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[일정알림]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[일정알림](
	[알림ID] [int] IDENTITY(1,1) NOT NULL,
	[일정ID] [int] NOT NULL,
	[알림유형] [nvarchar](20) NOT NULL,
	[분전] [int] NOT NULL,
	[다음알림일시] [datetime2](0) NULL,
	[활성] [bit] NOT NULL,
	[생성일시] [datetime2](0) NOT NULL,
	[수정일시] [datetime2](0) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[알림ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[일정완료]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[일정완료](
	[완료ID] [int] IDENTITY(1,1) NOT NULL,
	[일정ID] [int] NOT NULL,
	[발생일자] [date] NOT NULL,
	[완료일시] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[완료ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_일정완료] UNIQUE NONCLUSTERED 
(
	[일정ID] ASC,
	[발생일자] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[재산사건상담]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[재산사건상담](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[납세자ID] [int] NOT NULL,
	[사건ID] [int] NOT NULL,
	[상담일] [date] NOT NULL,
	[작성일시] [datetime] NOT NULL,
	[내용] [nvarchar](max) NOT NULL,
	[중요] [bit] NOT NULL,
	[사건구분] [nvarchar](10) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[재산상담사건]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[재산상담사건](
	[상담ID] [int] IDENTITY(1,1) NOT NULL,
	[납세자ID] [int] NOT NULL,
	[상담일자] [date] NOT NULL,
	[등록일시] [datetime2](0) NOT NULL,
	[메모] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[상담ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Index [IX_AllowanceMaster_ClientId]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_AllowanceMaster_ClientId] ON [dbo].[AllowanceMaster]
(
	[ClientId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_DeductionMaster_ClientId]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_DeductionMaster_ClientId] ON [dbo].[DeductionMaster]
(
	[ClientId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_EmployeeAllowances_EmployeeId]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_EmployeeAllowances_EmployeeId] ON [dbo].[EmployeeAllowances]
(
	[EmployeeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_EmployeeDeductions_EmployeeId]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_EmployeeDeductions_EmployeeId] ON [dbo].[EmployeeDeductions]
(
	[EmployeeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_EmployeeItems_EmployeeId]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_EmployeeItems_EmployeeId] ON [dbo].[EmployeePayrollItems]
(
	[EmployeeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Employees_Client_Target]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_Employees_Client_Target] ON [dbo].[Employees]
(
	[ClientId] ASC,
	[UseEmail] ASC
)
INCLUDE([EmployeeId],[EmailTo]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Employees_ClientId]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_Employees_ClientId] ON [dbo].[Employees]
(
	[ClientId] ASC
)
INCLUDE([UseEmail],[EmailTo],[Name]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UQ_Employees_Client_EmpNo]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UQ_Employees_Client_EmpNo] ON [dbo].[Employees]
(
	[ClientId] ASC,
	[EmpNo] ASC
)
WHERE ([EmpNo] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_MailLog_ClientYmDocEmp]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_MailLog_ClientYmDocEmp] ON [dbo].[PayrollMailLog]
(
	[ClientId] ASC,
	[Ym] ASC,
	[DocType] ASC,
	[EmployeeId] ASC,
	[Status] ASC
)
INCLUDE([SentAt]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_MailLog_ClientYmType]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_MailLog_ClientYmType] ON [dbo].[PayrollMailLog]
(
	[ClientId] ASC,
	[Ym] ASC,
	[DocType] ASC,
	[Status] ASC,
	[EmployeeId] ASC
)
INCLUDE([SentAt]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_MonthlyAdjustments_EmployeeYm]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_MonthlyAdjustments_EmployeeYm] ON [dbo].[PayrollMonthlyAdjustments]
(
	[EmployeeId] ASC,
	[Ym] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_MonthlyItems_EmployeeYm]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_MonthlyItems_EmployeeYm] ON [dbo].[PayrollMonthlyItems]
(
	[EmployeeId] ASC,
	[Ym] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PayrollResults_CalculatedAt]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_PayrollResults_CalculatedAt] ON [dbo].[PayrollResults]
(
	[CalculatedAt] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PayrollResults_Client_YearMonth]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_PayrollResults_Client_YearMonth] ON [dbo].[PayrollResults]
(
	[ClientId] ASC,
	[Year] ASC,
	[Month] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PayrollResults_Employee_YearMonth]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_PayrollResults_Employee_YearMonth] ON [dbo].[PayrollResults]
(
	[EmployeeId] ASC,
	[Year] ASC,
	[Month] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PayrollStatement_ClientYearMonth]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_PayrollStatement_ClientYearMonth] ON [dbo].[PayrollStatement]
(
	[ClientId] ASC,
	[Year] ASC,
	[Month] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PayrollStatement_EmployeeYearMonth]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_PayrollStatement_EmployeeYearMonth] ON [dbo].[PayrollStatement]
(
	[EmployeeId] ASC,
	[Year] ASC,
	[Month] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PayrollStatementDetail_StatementId]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_PayrollStatementDetail_StatementId] ON [dbo].[PayrollStatementDetail]
(
	[StatementId] ASC,
	[IsDeleted] ASC,
	[DisplayOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_PayrollStatementModification_StatementId]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_PayrollStatementModification_StatementId] ON [dbo].[PayrollStatementModification]
(
	[StatementId] ASC,
	[ModifiedAt] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_급여발송로그_연월결과일시]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_급여발송로그_연월결과일시] ON [dbo].[급여발송로그]
(
	[연월] ASC,
	[발송결과] ASC,
	[발송일시] ASC
)
INCLUDE([거래처ID],[직원ID],[문서유형],[수신자]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_급여발송로그_거래처직원연월문서]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_급여발송로그_거래처직원연월문서] ON [dbo].[급여발송로그]
(
	[거래처ID] ASC,
	[직원ID] ASC,
	[연월] ASC,
	[문서유형] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [UX_담당자_이름]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_담당자_이름] ON [dbo].[담당자]
(
	[이름] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_발송로그_급여성공]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_발송로그_급여성공] ON [dbo].[발송로그]
(
	[발송유형] ASC,
	[발송결과] ASC,
	[발송일시] ASC
)
INCLUDE([회사ID],[회사명]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_상담_납세자]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_상담_납세자] ON [dbo].[상담로그]
(
	[납세자ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_상담_사건]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_상담_사건] ON [dbo].[상담로그]
(
	[사건ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_상담_신고서]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_상담_신고서] ON [dbo].[상담로그]
(
	[신고서ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_상담_자산]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_상담_자산] ON [dbo].[상담로그]
(
	[자산ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_상증사건_납세자_날짜]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_상증사건_납세자_날짜] ON [dbo].[상속증여사건]
(
	[납세자ID] ASC,
	[사건일자] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_양도신고서_납세자_구분]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_양도신고서_납세자_구분] ON [dbo].[양도신고서]
(
	[납세자ID] ASC,
	[신고구분] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_양도자산_납세자_날짜]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_양도자산_납세자_날짜] ON [dbo].[양도자산]
(
	[납세자ID] ASC,
	[양도일자] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_일정_기한_상태]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_일정_기한_상태] ON [dbo].[일정]
(
	[신고기한] ASC,
	[상태] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_일정_신고기한]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_일정_신고기한] ON [dbo].[일정]
(
	[신고기한] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_일정_출처참조]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_일정_출처참조] ON [dbo].[일정]
(
	[출처] ASC,
	[참조구분] ASC,
	[참조ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [IX_일정_표시일자]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_일정_표시일자] ON [dbo].[일정]
(
	[표시일자] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_일정알림_다음알림일시]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_일정알림_다음알림일시] ON [dbo].[일정알림]
(
	[다음알림일시] ASC
)
WHERE ([활성]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_일정알림_일정ID]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_일정알림_일정ID] ON [dbo].[일정알림]
(
	[일정ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [IX_채팅메시지_대화키_메시지ID]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_채팅메시지_대화키_메시지ID] ON [dbo].[채팅메시지]
(
	[대화키] ASC,
	[메시지ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_채팅메시지_받는이_읽은시각_NULL_메시지ID]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_채팅메시지_받는이_읽은시각_NULL_메시지ID] ON [dbo].[채팅메시지]
(
	[받는이] ASC,
	[메시지ID] ASC
)
WHERE ([읽은시각] IS NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_채팅메시지_보낸이_받는이_메시지ID]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_채팅메시지_보낸이_받는이_메시지ID] ON [dbo].[채팅메시지]
(
	[보낸이] ASC,
	[받는이] ASC,
	[메시지ID] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_채팅파일_MIME_파일ID]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_채팅파일_MIME_파일ID] ON [dbo].[채팅파일]
(
	[MIME] ASC,
	[파일ID] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_채팅파일_업로더_파일ID]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_채팅파일_업로더_파일ID] ON [dbo].[채팅파일]
(
	[업로더] ASC,
	[파일ID] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_현금영수증_납세자_사건]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_현금영수증_납세자_사건] ON [dbo].[현금영수증]
(
	[납세자ID] ASC,
	[사건구분] ASC,
	[사건ID] ASC
)
INCLUDE([완료],[등록일]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_현금영수증_상태]    Script Date: 2025-12-30 오전 11:45:02 ******/
CREATE NONCLUSTERED INDEX [IX_현금영수증_상태] ON [dbo].[현금영수증]
(
	[완료] ASC,
	[등록일] DESC
)
INCLUDE([납세자ID],[사건구분],[사건ID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [dbo].[AllowanceMaster] ADD  DEFAULT ((1)) FOR [IsTaxable]
GO
ALTER TABLE [dbo].[AllowanceMaster] ADD  DEFAULT ((1)) FOR [IsMonthlyDefault]
GO
ALTER TABLE [dbo].[AllowanceMaster] ADD  DEFAULT ((0)) FOR [DefaultAmount]
GO
ALTER TABLE [dbo].[AllowanceMaster] ADD  DEFAULT ((0)) FOR [DisplayOrder]
GO
ALTER TABLE [dbo].[AllowanceMaster] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[AllowanceMaster] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[AllowanceMaster] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[AppSettings] ADD  DEFAULT ((1)) FOR [Id]
GO
ALTER TABLE [dbo].[AppSettings] ADD  DEFAULT ('http://localhost:8000') FOR [ServerUrl]
GO
ALTER TABLE [dbo].[AppSettings] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[DeductionMaster] ADD  DEFAULT ('general') FOR [DeductionType]
GO
ALTER TABLE [dbo].[DeductionMaster] ADD  DEFAULT ((0)) FOR [IsPreTax]
GO
ALTER TABLE [dbo].[DeductionMaster] ADD  DEFAULT ((1)) FOR [IsMonthlyDefault]
GO
ALTER TABLE [dbo].[DeductionMaster] ADD  DEFAULT ((0)) FOR [DefaultAmount]
GO
ALTER TABLE [dbo].[DeductionMaster] ADD  DEFAULT ((0)) FOR [DisplayOrder]
GO
ALTER TABLE [dbo].[DeductionMaster] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[DeductionMaster] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[DeductionMaster] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[EmployeeAllowances] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[EmployeeAllowances] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[EmployeeAllowances] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[EmployeeDeductions] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[EmployeeDeductions] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[EmployeeDeductions] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[EmployeePayrollItems] ADD  DEFAULT ((1)) FOR [IsEnabled]
GO
ALTER TABLE [dbo].[EmployeePayrollItems] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT (N'regular') FOR [EmploymentType]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT (N'HOURLY') FOR [SalaryType]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((0)) FOR [BaseSalary]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((0)) FOR [HourlyRate]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((209)) FOR [NormalHours]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((0)) FOR [FoodAllowance]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((0)) FOR [CarAllowance]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((0)) FOR [UseEmail]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((1)) FOR [HasNationalPension]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((1)) FOR [HasHealthInsurance]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((1)) FOR [HasEmploymentInsurance]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ('salary') FOR [HealthInsuranceBasis]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((1)) FOR [TaxDependents]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((0)) FOR [ChildrenCount]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((0)) FOR [TaxFreeMeal]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((0)) FOR [TaxFreeCarMaintenance]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((0)) FOR [OtherTaxFree]
GO
ALTER TABLE [dbo].[Employees] ADD  DEFAULT ((100)) FOR [IncomeTaxRate]
GO
ALTER TABLE [dbo].[PayrollDocLog] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[PayrollItemTemplate] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[PayrollItemTemplate] ADD  DEFAULT ((0)) FOR [DisplayOrder]
GO
ALTER TABLE [dbo].[PayrollItemTemplate] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[PayrollMailLog] ADD  DEFAULT (sysutcdatetime()) FOR [SentAt]
GO
ALTER TABLE [dbo].[PayrollMonthlyAdjustments] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  DEFAULT ((0)) FOR [WorkHours]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  DEFAULT ((0)) FOR [Bonus]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  DEFAULT ((0)) FOR [OvertimeHours]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  DEFAULT ((0)) FOR [NightHours]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  DEFAULT ((0)) FOR [HolidayHours]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  DEFAULT ((0)) FOR [ExtraAllowance]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  DEFAULT ((0)) FOR [ExtraDeduction]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  CONSTRAINT [DF_PayrollMonthlyInput_WeeklyHours]  DEFAULT ((40.0)) FOR [WeeklyHours]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  CONSTRAINT [DF_PayrollMonthlyInput_WeekCount]  DEFAULT ((4)) FOR [WeekCount]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] ADD  DEFAULT ((0)) FOR [IsDurunuri]
GO
ALTER TABLE [dbo].[PayrollMonthlyItems] ADD  DEFAULT ((0)) FOR [Amount]
GO
ALTER TABLE [dbo].[PayrollMonthlyItems] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[PayrollMonthlyItems] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [OvertimeAllowance]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [NightAllowance]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [HolidayAllowance]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [WeeklyHolidayPay]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [Bonus]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [AdditionalAllowance1Amount]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [AdditionalAllowance2Amount]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [NationalPension]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [HealthInsurance]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [LongTermCare]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [EmploymentInsurance]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [IncomeTax]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [LocalIncomeTax]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [AdditionalDeduction1Amount]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [AdditionalDeduction2Amount]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT (sysutcdatetime()) FOR [CalculatedAt]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ('system') FOR [CalculatedBy]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [IsPdfGenerated]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [IsEmailSent]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [IsConfirmed]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [YearEndAdjustmentAmount]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [HealthInsurancePremiumAdjustment]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [DuruNuriEmployerContribution]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [DuruNuriEmployeeContribution]
GO
ALTER TABLE [dbo].[PayrollResults] ADD  DEFAULT ((0)) FOR [DuruNuriApplied]
GO
ALTER TABLE [dbo].[PayrollStatement] ADD  DEFAULT ((0)) FOR [TotalEarnings]
GO
ALTER TABLE [dbo].[PayrollStatement] ADD  DEFAULT ((0)) FOR [TotalDeductions]
GO
ALTER TABLE [dbo].[PayrollStatement] ADD  DEFAULT ((0)) FOR [NetPay]
GO
ALTER TABLE [dbo].[PayrollStatement] ADD  DEFAULT ((0)) FOR [IsFinalized]
GO
ALTER TABLE [dbo].[PayrollStatement] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[PayrollStatement] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[PayrollStatementDetail] ADD  DEFAULT ((0)) FOR [DisplayOrder]
GO
ALTER TABLE [dbo].[PayrollStatementDetail] ADD  DEFAULT ((0)) FOR [IsDeleted]
GO
ALTER TABLE [dbo].[PayrollStatementDetail] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
GO
ALTER TABLE [dbo].[PayrollStatementDetail] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[PayrollStatementModification] ADD  DEFAULT (sysutcdatetime()) FOR [ModifiedAt]
GO
ALTER TABLE [dbo].[SmtpConfig] ADD  DEFAULT ((1)) FOR [Id]
GO
ALTER TABLE [dbo].[SmtpConfig] ADD  DEFAULT ((587)) FOR [Port]
GO
ALTER TABLE [dbo].[SmtpConfig] ADD  DEFAULT ((1)) FOR [UseSSL]
GO
ALTER TABLE [dbo].[SmtpConfig] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
GO
ALTER TABLE [dbo].[거래처] ADD  DEFAULT ((0)) FOR [Has5OrMoreWorkers]
GO
ALTER TABLE [dbo].[거래처] ADD  DEFAULT (N'{clientName} {year}년 {month}월 {workerName} 급여명세서') FOR [EmailSubjectTemplate]
GO
ALTER TABLE [dbo].[거래처] ADD  DEFAULT (N'안녕하세요,

{year}년 {month}월 급여명세서를 발송드립니다.

감사합니다.') FOR [EmailBodyTemplate]
GO
ALTER TABLE [dbo].[거래처] ADD  CONSTRAINT [DF_거래처_발송설정]  DEFAULT (N'사용안함') FOR [발송설정]
GO
ALTER TABLE [dbo].[급여발송로그] ADD  CONSTRAINT [DF_급여발송로그_재시도]  DEFAULT ((0)) FOR [재시도횟수]
GO
ALTER TABLE [dbo].[급여발송로그] ADD  CONSTRAINT [DF_급여발송로그_발송일시]  DEFAULT (sysutcdatetime()) FOR [발송일시]
GO
ALTER TABLE [dbo].[급여발송로그] ADD  CONSTRAINT [DF_급여발송로그_발송방식]  DEFAULT (N'급여') FOR [발송방식]
GO
ALTER TABLE [dbo].[급여발송로그] ADD  CONSTRAINT [DF_급여발송로그_발송경로]  DEFAULT (N'자동') FOR [발송경로]
GO
ALTER TABLE [dbo].[발송로그] ADD  DEFAULT ((0)) FOR [재시도횟수]
GO
ALTER TABLE [dbo].[발송로그] ADD  DEFAULT (getdate()) FOR [발송일시]
GO
ALTER TABLE [dbo].[상담로그] ADD  DEFAULT (CONVERT([date],getdate())) FOR [상담일]
GO
ALTER TABLE [dbo].[상담로그] ADD  DEFAULT (getdate()) FOR [작성일시]
GO
ALTER TABLE [dbo].[상담로그] ADD  DEFAULT ((0)) FOR [중요]
GO
ALTER TABLE [dbo].[상속증여사건] ADD  DEFAULT (N'예정') FOR [상태]
GO
ALTER TABLE [dbo].[알림로그] ADD  CONSTRAINT [DF_알림로그_발송]  DEFAULT (sysutcdatetime()) FOR [발송일시]
GO
ALTER TABLE [dbo].[양도신고서] ADD  DEFAULT (N'예정') FOR [상태]
GO
ALTER TABLE [dbo].[원천세관리] ADD  CONSTRAINT [DF_원천세관리_상태]  DEFAULT (N'해당없음') FOR [상태]
GO
ALTER TABLE [dbo].[원천세관리] ADD  CONSTRAINT [DF_원천세관리_카카오발송]  DEFAULT ((0)) FOR [카카오발송]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [홈택스등록]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [두란DB업로드]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [세무사랑업로드]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [CMS등록]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [국민연금사업장]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [건강보험사업장]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [고용산재사업장]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [자격취득신고]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [건강보험EDI]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [국민연금EDI]
GO
ALTER TABLE [dbo].[원천세업무] ADD  DEFAULT ((0)) FOR [사대보험미가입]
GO
ALTER TABLE [dbo].[원천세업무] ADD  CONSTRAINT [DF_원천세업무_수정일시]  DEFAULT (sysutcdatetime()) FOR [수정일시]
GO
ALTER TABLE [dbo].[일정] ADD  DEFAULT ((0)) FOR [중요]
GO
ALTER TABLE [dbo].[일정] ADD  DEFAULT (N'예정') FOR [상태]
GO
ALTER TABLE [dbo].[일정] ADD  CONSTRAINT [DF_일정_종일]  DEFAULT ((1)) FOR [종일]
GO
ALTER TABLE [dbo].[일정] ADD  CONSTRAINT [DF_일정_출처]  DEFAULT (N'MANUAL') FOR [출처]
GO
ALTER TABLE [dbo].[일정] ADD  CONSTRAINT [DF_일정_생성]  DEFAULT (sysutcdatetime()) FOR [생성일시]
GO
ALTER TABLE [dbo].[일정] ADD  CONSTRAINT [DF_일정_수정]  DEFAULT (sysutcdatetime()) FOR [수정일시]
GO
ALTER TABLE [dbo].[일정알림] ADD  CONSTRAINT [DF_일정알림_유형]  DEFAULT (N'POPUP') FOR [알림유형]
GO
ALTER TABLE [dbo].[일정알림] ADD  CONSTRAINT [DF_일정알림_분전]  DEFAULT ((0)) FOR [분전]
GO
ALTER TABLE [dbo].[일정알림] ADD  CONSTRAINT [DF_일정알림_활성]  DEFAULT ((1)) FOR [활성]
GO
ALTER TABLE [dbo].[일정알림] ADD  CONSTRAINT [DF_일정알림_생성]  DEFAULT (sysutcdatetime()) FOR [생성일시]
GO
ALTER TABLE [dbo].[일정알림] ADD  CONSTRAINT [DF_일정알림_수정]  DEFAULT (sysutcdatetime()) FOR [수정일시]
GO
ALTER TABLE [dbo].[일정완료] ADD  DEFAULT (sysutcdatetime()) FOR [완료일시]
GO
ALTER TABLE [dbo].[재산사건상담] ADD  DEFAULT (CONVERT([date],getdate())) FOR [상담일]
GO
ALTER TABLE [dbo].[재산사건상담] ADD  DEFAULT (getdate()) FOR [작성일시]
GO
ALTER TABLE [dbo].[재산사건상담] ADD  DEFAULT ((0)) FOR [중요]
GO
ALTER TABLE [dbo].[재산상담사건] ADD  CONSTRAINT [DF_재산상담사건_상담일자]  DEFAULT (CONVERT([date],getdate())) FOR [상담일자]
GO
ALTER TABLE [dbo].[재산상담사건] ADD  CONSTRAINT [DF_재산상담사건_등록일시]  DEFAULT (sysutcdatetime()) FOR [등록일시]
GO
ALTER TABLE [dbo].[채팅메시지] ADD  CONSTRAINT [DF_채팅메시지_보낸시각]  DEFAULT (sysutcdatetime()) FOR [보낸시각]
GO
ALTER TABLE [dbo].[채팅파일] ADD  CONSTRAINT [DF_채팅파일_업로드시각]  DEFAULT (sysutcdatetime()) FOR [업로드시각]
GO
ALTER TABLE [dbo].[현금영수증] ADD  CONSTRAINT [DF_현금영수증_등록일]  DEFAULT (CONVERT([date],getdate())) FOR [등록일]
GO
ALTER TABLE [dbo].[현금영수증] ADD  CONSTRAINT [DF_현금영수증_완료]  DEFAULT ((0)) FOR [완료]
GO
ALTER TABLE [dbo].[AllowanceMaster]  WITH CHECK ADD  CONSTRAINT [FK_AllowanceMaster_Client] FOREIGN KEY([ClientId])
REFERENCES [dbo].[거래처] ([ID])
GO
ALTER TABLE [dbo].[AllowanceMaster] CHECK CONSTRAINT [FK_AllowanceMaster_Client]
GO
ALTER TABLE [dbo].[DeductionMaster]  WITH CHECK ADD  CONSTRAINT [FK_DeductionMaster_Client] FOREIGN KEY([ClientId])
REFERENCES [dbo].[거래처] ([ID])
GO
ALTER TABLE [dbo].[DeductionMaster] CHECK CONSTRAINT [FK_DeductionMaster_Client]
GO
ALTER TABLE [dbo].[EmployeeAllowances]  WITH CHECK ADD  CONSTRAINT [FK_EmployeeAllowances_Employee] FOREIGN KEY([EmployeeId])
REFERENCES [dbo].[Employees] ([EmployeeId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[EmployeeAllowances] CHECK CONSTRAINT [FK_EmployeeAllowances_Employee]
GO
ALTER TABLE [dbo].[EmployeeAllowances]  WITH CHECK ADD  CONSTRAINT [FK_EmployeeAllowances_Master] FOREIGN KEY([AllowanceId])
REFERENCES [dbo].[AllowanceMaster] ([AllowanceId])
GO
ALTER TABLE [dbo].[EmployeeAllowances] CHECK CONSTRAINT [FK_EmployeeAllowances_Master]
GO
ALTER TABLE [dbo].[EmployeeDeductions]  WITH CHECK ADD  CONSTRAINT [FK_EmployeeDeductions_Employee] FOREIGN KEY([EmployeeId])
REFERENCES [dbo].[Employees] ([EmployeeId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[EmployeeDeductions] CHECK CONSTRAINT [FK_EmployeeDeductions_Employee]
GO
ALTER TABLE [dbo].[EmployeeDeductions]  WITH CHECK ADD  CONSTRAINT [FK_EmployeeDeductions_Master] FOREIGN KEY([DeductionId])
REFERENCES [dbo].[DeductionMaster] ([DeductionId])
GO
ALTER TABLE [dbo].[EmployeeDeductions] CHECK CONSTRAINT [FK_EmployeeDeductions_Master]
GO
ALTER TABLE [dbo].[EmployeePayrollItems]  WITH CHECK ADD  CONSTRAINT [FK_EmployeeItems_Employee] FOREIGN KEY([EmployeeId])
REFERENCES [dbo].[Employees] ([EmployeeId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[EmployeePayrollItems] CHECK CONSTRAINT [FK_EmployeeItems_Employee]
GO
ALTER TABLE [dbo].[EmployeePayrollItems]  WITH CHECK ADD  CONSTRAINT [FK_EmployeeItems_Template] FOREIGN KEY([ItemId])
REFERENCES [dbo].[PayrollItemTemplate] ([Id])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[EmployeePayrollItems] CHECK CONSTRAINT [FK_EmployeeItems_Template]
GO
ALTER TABLE [dbo].[PayrollMonthlyAdjustments]  WITH CHECK ADD  CONSTRAINT [FK_MonthlyAdjustments_Employee] FOREIGN KEY([EmployeeId])
REFERENCES [dbo].[Employees] ([EmployeeId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PayrollMonthlyAdjustments] CHECK CONSTRAINT [FK_MonthlyAdjustments_Employee]
GO
ALTER TABLE [dbo].[PayrollMonthlyInput]  WITH CHECK ADD  CONSTRAINT [FK_PayrollMonthlyInput_Employees] FOREIGN KEY([EmployeeId])
REFERENCES [dbo].[Employees] ([EmployeeId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PayrollMonthlyInput] CHECK CONSTRAINT [FK_PayrollMonthlyInput_Employees]
GO
ALTER TABLE [dbo].[PayrollMonthlyItems]  WITH CHECK ADD  CONSTRAINT [FK_MonthlyItems_Employee] FOREIGN KEY([EmployeeId])
REFERENCES [dbo].[Employees] ([EmployeeId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PayrollMonthlyItems] CHECK CONSTRAINT [FK_MonthlyItems_Employee]
GO
ALTER TABLE [dbo].[PayrollMonthlyItems]  WITH CHECK ADD  CONSTRAINT [FK_MonthlyItems_Template] FOREIGN KEY([ItemId])
REFERENCES [dbo].[PayrollItemTemplate] ([Id])
GO
ALTER TABLE [dbo].[PayrollMonthlyItems] CHECK CONSTRAINT [FK_MonthlyItems_Template]
GO
ALTER TABLE [dbo].[PayrollResults]  WITH CHECK ADD  CONSTRAINT [FK_PayrollResults_Clients] FOREIGN KEY([ClientId])
REFERENCES [dbo].[거래처] ([ID])
GO
ALTER TABLE [dbo].[PayrollResults] CHECK CONSTRAINT [FK_PayrollResults_Clients]
GO
ALTER TABLE [dbo].[PayrollResults]  WITH CHECK ADD  CONSTRAINT [FK_PayrollResults_Employees] FOREIGN KEY([EmployeeId])
REFERENCES [dbo].[Employees] ([EmployeeId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PayrollResults] CHECK CONSTRAINT [FK_PayrollResults_Employees]
GO
ALTER TABLE [dbo].[PayrollStatement]  WITH CHECK ADD FOREIGN KEY([ClientId])
REFERENCES [dbo].[거래처] ([ID])
GO
ALTER TABLE [dbo].[PayrollStatement]  WITH CHECK ADD FOREIGN KEY([EmployeeId])
REFERENCES [dbo].[Employees] ([EmployeeId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PayrollStatementDetail]  WITH CHECK ADD FOREIGN KEY([StatementId])
REFERENCES [dbo].[PayrollStatement] ([StatementId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PayrollStatementModification]  WITH CHECK ADD  CONSTRAINT [FK_PayrollStatementModification_Statement] FOREIGN KEY([StatementId])
REFERENCES [dbo].[PayrollStatement] ([StatementId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PayrollStatementModification] CHECK CONSTRAINT [FK_PayrollStatementModification_Statement]
GO
ALTER TABLE [dbo].[급여발송로그]  WITH CHECK ADD  CONSTRAINT [FK_급여발송로그_거래처] FOREIGN KEY([거래처ID])
REFERENCES [dbo].[거래처] ([ID])
GO
ALTER TABLE [dbo].[급여발송로그] CHECK CONSTRAINT [FK_급여발송로그_거래처]
GO
ALTER TABLE [dbo].[급여발송로그]  WITH CHECK ADD  CONSTRAINT [FK_급여발송로그_직원] FOREIGN KEY([직원ID])
REFERENCES [dbo].[Employees] ([EmployeeId])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[급여발송로그] CHECK CONSTRAINT [FK_급여발송로그_직원]
GO
ALTER TABLE [dbo].[상담로그]  WITH CHECK ADD FOREIGN KEY([납세자ID])
REFERENCES [dbo].[납세자] ([납세자ID])
GO
ALTER TABLE [dbo].[상담로그]  WITH CHECK ADD FOREIGN KEY([사건ID])
REFERENCES [dbo].[상속증여사건] ([사건ID])
GO
ALTER TABLE [dbo].[상담로그]  WITH CHECK ADD FOREIGN KEY([신고서ID])
REFERENCES [dbo].[양도신고서] ([신고서ID])
GO
ALTER TABLE [dbo].[상담로그]  WITH CHECK ADD FOREIGN KEY([자산ID])
REFERENCES [dbo].[양도자산] ([자산ID])
GO
ALTER TABLE [dbo].[상담로그]  WITH CHECK ADD  CONSTRAINT [FK_상담로그_거래처] FOREIGN KEY([회사ID])
REFERENCES [dbo].[거래처] ([ID])
GO
ALTER TABLE [dbo].[상담로그] CHECK CONSTRAINT [FK_상담로그_거래처]
GO
ALTER TABLE [dbo].[상속증여사건]  WITH CHECK ADD FOREIGN KEY([납세자ID])
REFERENCES [dbo].[납세자] ([납세자ID])
GO
ALTER TABLE [dbo].[신고자산연결]  WITH CHECK ADD FOREIGN KEY([신고서ID])
REFERENCES [dbo].[양도신고서] ([신고서ID])
GO
ALTER TABLE [dbo].[신고자산연결]  WITH CHECK ADD FOREIGN KEY([자산ID])
REFERENCES [dbo].[양도자산] ([자산ID])
GO
ALTER TABLE [dbo].[알림로그]  WITH CHECK ADD  CONSTRAINT [FK_알림로그_알림] FOREIGN KEY([알림ID])
REFERENCES [dbo].[일정알림] ([알림ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[알림로그] CHECK CONSTRAINT [FK_알림로그_알림]
GO
ALTER TABLE [dbo].[양도신고서]  WITH CHECK ADD FOREIGN KEY([납세자ID])
REFERENCES [dbo].[납세자] ([납세자ID])
GO
ALTER TABLE [dbo].[양도자산]  WITH CHECK ADD FOREIGN KEY([납세자ID])
REFERENCES [dbo].[납세자] ([납세자ID])
GO
ALTER TABLE [dbo].[원천세관리]  WITH CHECK ADD  CONSTRAINT [FK_원천세관리_거래처] FOREIGN KEY([회사ID])
REFERENCES [dbo].[거래처] ([ID])
GO
ALTER TABLE [dbo].[원천세관리] CHECK CONSTRAINT [FK_원천세관리_거래처]
GO
ALTER TABLE [dbo].[원천세업무]  WITH CHECK ADD FOREIGN KEY([회사ID])
REFERENCES [dbo].[거래처] ([ID])
GO
ALTER TABLE [dbo].[일정]  WITH CHECK ADD FOREIGN KEY([거래처ID])
REFERENCES [dbo].[거래처] ([ID])
GO
ALTER TABLE [dbo].[일정]  WITH CHECK ADD FOREIGN KEY([납세자ID])
REFERENCES [dbo].[납세자] ([납세자ID])
GO
ALTER TABLE [dbo].[일정알림]  WITH CHECK ADD  CONSTRAINT [FK_일정알림_일정] FOREIGN KEY([일정ID])
REFERENCES [dbo].[일정] ([일정ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[일정알림] CHECK CONSTRAINT [FK_일정알림_일정]
GO
ALTER TABLE [dbo].[일정완료]  WITH CHECK ADD  CONSTRAINT [FK_일정완료_일정] FOREIGN KEY([일정ID])
REFERENCES [dbo].[일정] ([일정ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[일정완료] CHECK CONSTRAINT [FK_일정완료_일정]
GO
ALTER TABLE [dbo].[재산사건상담]  WITH CHECK ADD FOREIGN KEY([납세자ID])
REFERENCES [dbo].[납세자] ([납세자ID])
GO
ALTER TABLE [dbo].[재산상담사건]  WITH CHECK ADD  CONSTRAINT [FK_재산상담사건_납세자] FOREIGN KEY([납세자ID])
REFERENCES [dbo].[납세자] ([납세자ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[재산상담사건] CHECK CONSTRAINT [FK_재산상담사건_납세자]
GO
ALTER TABLE [dbo].[채팅메시지]  WITH CHECK ADD  CONSTRAINT [FK_채팅메시지_받는이_담당자] FOREIGN KEY([받는이])
REFERENCES [dbo].[담당자] ([이름])
GO
ALTER TABLE [dbo].[채팅메시지] CHECK CONSTRAINT [FK_채팅메시지_받는이_담당자]
GO
ALTER TABLE [dbo].[채팅메시지]  WITH CHECK ADD  CONSTRAINT [FK_채팅메시지_보낸이_담당자] FOREIGN KEY([보낸이])
REFERENCES [dbo].[담당자] ([이름])
GO
ALTER TABLE [dbo].[채팅메시지] CHECK CONSTRAINT [FK_채팅메시지_보낸이_담당자]
GO
ALTER TABLE [dbo].[채팅메시지]  WITH CHECK ADD  CONSTRAINT [FK_채팅메시지_파일] FOREIGN KEY([파일ID])
REFERENCES [dbo].[채팅파일] ([파일ID])
GO
ALTER TABLE [dbo].[채팅메시지] CHECK CONSTRAINT [FK_채팅메시지_파일]
GO
ALTER TABLE [dbo].[AppSettings]  WITH CHECK ADD  CONSTRAINT [CHK_AppSettings_SingleRow] CHECK  (([Id]=(1)))
GO
ALTER TABLE [dbo].[AppSettings] CHECK CONSTRAINT [CHK_AppSettings_SingleRow]
GO
ALTER TABLE [dbo].[PayrollItemTemplate]  WITH CHECK ADD  CONSTRAINT [CHK_ItemType] CHECK  (([ItemType]='deduction' OR [ItemType]='allowance'))
GO
ALTER TABLE [dbo].[PayrollItemTemplate] CHECK CONSTRAINT [CHK_ItemType]
GO
ALTER TABLE [dbo].[PayrollMonthlyAdjustments]  WITH CHECK ADD  CONSTRAINT [CHK_MonthlyAdjustments_Type] CHECK  (([Type]='deduction' OR [Type]='allowance'))
GO
ALTER TABLE [dbo].[PayrollMonthlyAdjustments] CHECK CONSTRAINT [CHK_MonthlyAdjustments_Type]
GO
ALTER TABLE [dbo].[PayrollResults]  WITH CHECK ADD  CONSTRAINT [CHK_PayrollResults_YearMonth] CHECK  (([Year]>=(2020) AND [Year]<=(2100) AND [Month]>=(1) AND [Month]<=(12)))
GO
ALTER TABLE [dbo].[PayrollResults] CHECK CONSTRAINT [CHK_PayrollResults_YearMonth]
GO
ALTER TABLE [dbo].[SmtpConfig]  WITH CHECK ADD  CONSTRAINT [CHK_SmtpConfig_SingleRow] CHECK  (([Id]=(1)))
GO
ALTER TABLE [dbo].[SmtpConfig] CHECK CONSTRAINT [CHK_SmtpConfig_SingleRow]
GO
ALTER TABLE [dbo].[거래처]  WITH CHECK ADD  CONSTRAINT [CK_거래처_발송설정] CHECK  (([발송설정]=N'사용안함' OR [발송설정]=N'둘다' OR [발송설정]=N'매크로' OR [발송설정]=N'급여'))
GO
ALTER TABLE [dbo].[거래처] CHECK CONSTRAINT [CK_거래처_발송설정]
GO
ALTER TABLE [dbo].[급여발송로그]  WITH CHECK ADD  CONSTRAINT [CK_급여발송로그_발송결과] CHECK  (([발송결과]=N'건너뜀' OR [발송결과]=N'실패' OR [발송결과]=N'성공'))
GO
ALTER TABLE [dbo].[급여발송로그] CHECK CONSTRAINT [CK_급여발송로그_발송결과]
GO
ALTER TABLE [dbo].[급여발송로그]  WITH CHECK ADD  CONSTRAINT [CK_급여발송로그_발송경로] CHECK  (([발송경로]=N'수동' OR [발송경로]=N'자동'))
GO
ALTER TABLE [dbo].[급여발송로그] CHECK CONSTRAINT [CK_급여발송로그_발송경로]
GO
ALTER TABLE [dbo].[급여발송로그]  WITH CHECK ADD  CONSTRAINT [CK_급여발송로그_발송방식] CHECK  (([발송방식]=N'급여'))
GO
ALTER TABLE [dbo].[급여발송로그] CHECK CONSTRAINT [CK_급여발송로그_발송방식]
GO
ALTER TABLE [dbo].[상속증여사건]  WITH CHECK ADD  CONSTRAINT [CK__상속증여사건__사건구분__09A971A2] CHECK  (([사건구분]=N'증여' OR [사건구분]=N'상속'))
GO
ALTER TABLE [dbo].[상속증여사건] CHECK CONSTRAINT [CK__상속증여사건__사건구분__09A971A2]
GO
ALTER TABLE [dbo].[양도신고서]  WITH CHECK ADD  CONSTRAINT [CK_양도신고서_신고구분] CHECK  (([신고구분]=N'양도'))
GO
ALTER TABLE [dbo].[양도신고서] CHECK CONSTRAINT [CK_양도신고서_신고구분]
GO
ALTER TABLE [dbo].[일정알림]  WITH CHECK ADD  CONSTRAINT [CK_일정알림_분전_nonneg] CHECK  (([분전]>=(0)))
GO
ALTER TABLE [dbo].[일정알림] CHECK CONSTRAINT [CK_일정알림_분전_nonneg]
GO
ALTER TABLE [dbo].[재산사건상담]  WITH CHECK ADD  CONSTRAINT [CK_재산사건상담_사건구분] CHECK  (([사건구분]=N'상담' OR [사건구분]=N'증여' OR [사건구분]=N'상속' OR [사건구분]=N'양도'))
GO
ALTER TABLE [dbo].[재산사건상담] CHECK CONSTRAINT [CK_재산사건상담_사건구분]
GO
ALTER TABLE [dbo].[채팅파일]  WITH CHECK ADD  CONSTRAINT [CK_채팅파일_저장방식] CHECK  (([저장방식]=N'BL' OR [저장방식]=N'FS'))
GO
ALTER TABLE [dbo].[채팅파일] CHECK CONSTRAINT [CK_채팅파일_저장방식]
GO
ALTER TABLE [dbo].[현금영수증]  WITH CHECK ADD  CONSTRAINT [CK_현금영수증_사건구분] CHECK  (([사건구분]=N'상담' OR [사건구분]=N'증여' OR [사건구분]=N'상속' OR [사건구분]=N'양도'))
GO
ALTER TABLE [dbo].[현금영수증] CHECK CONSTRAINT [CK_현금영수증_사건구분]
GO
/****** Object:  StoredProcedure [dbo].[p_현금영수증_토글]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[p_현금영수증_토글]
    @납세자ID int,
    @사건구분 nvarchar(10),
    @사건ID   int
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM dbo.현금영수증
        WHERE 사건구분=@사건구분 AND 사건ID=@사건ID
    )
    BEGIN
        UPDATE dbo.현금영수증
        SET 완료     = 1 - 완료,
            완료일시 = CASE WHEN 완료 = 0 THEN SYSUTCDATETIME() ELSE NULL END,
            납세자ID = @납세자ID  -- 최신 값으로 동기화(안전)
        WHERE 사건구분=@사건구분 AND 사건ID=@사건ID;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.현금영수증(납세자ID, 사건구분, 사건ID, 완료, 완료일시)
        VALUES(@납세자ID, @사건구분, @사건ID, 1, SYSUTCDATETIME());
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_chat_mark_read]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_chat_mark_read]
    @받는이 NVARCHAR(50),
    @보낸이 NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.채팅메시지
    SET 읽은시각 = SYSUTCDATETIME()
    WHERE 받는이 = @받는이
      AND 보낸이 = @보낸이
      AND 읽은시각 IS NULL;

    SELECT @@ROWCOUNT AS updated_rows;
END
GO
/****** Object:  StoredProcedure [dbo].[sp_chat_send_file_bl]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_chat_send_file_bl]
    @보낸이 NVARCHAR(50),
    @받는이 NVARCHAR(50),
    @원본파일명 NVARCHAR(255),
    @MIME NVARCHAR(100),
    @크기 BIGINT,
    @업로더 NVARCHAR(50),
    @콘텐츠 VARBINARY(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @파일ID INT, @메시지ID INT;

    INSERT INTO dbo.채팅파일(원본파일명, 콘텐츠, MIME, 크기, 업로더, 파일경로, 저장방식)
    VALUES(@원본파일명, @콘텐츠, @MIME, @크기, @업로더, NULL, N'BL');
    SET @파일ID = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO dbo.채팅메시지(보낸이, 받는이, 파일ID)
    VALUES(@보낸이, @받는이, @파일ID);
    SET @메시지ID = CAST(SCOPE_IDENTITY() AS INT);

    SELECT @파일ID AS 파일ID, @메시지ID AS 메시지ID;
END
GO
/****** Object:  StoredProcedure [dbo].[sp_chat_send_file_fs]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_chat_send_file_fs]
    @보낸이 NVARCHAR(50),
    @받는이 NVARCHAR(50),
    @원본파일명 NVARCHAR(255),
    @MIME NVARCHAR(100),
    @크기 BIGINT,
    @업로더 NVARCHAR(50),
    @파일경로 NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @파일ID INT, @메시지ID INT;

    INSERT INTO dbo.채팅파일(원본파일명, 콘텐츠, MIME, 크기, 업로더, 파일경로, 저장방식)
    VALUES(@원본파일명, NULL, @MIME, @크기, @업로더, @파일경로, N'FS');
    SET @파일ID = CAST(SCOPE_IDENTITY() AS INT);

    INSERT INTO dbo.채팅메시지(보낸이, 받는이, 파일ID)
    VALUES(@보낸이, @받는이, @파일ID);
    SET @메시지ID = CAST(SCOPE_IDENTITY() AS INT);

    SELECT @파일ID AS 파일ID, @메시지ID AS 메시지ID;
END
GO
/****** Object:  StoredProcedure [dbo].[sp_chat_send_text]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_chat_send_text]
    @보낸이 NVARCHAR(50),
    @받는이 NVARCHAR(50),
    @본문   NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.채팅메시지(보낸이, 받는이, 본문)
    VALUES(@보낸이, @받는이, @본문);

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS 메시지ID;
END
GO
/****** Object:  StoredProcedure [dbo].[sp_급여알림_자동생성]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [dbo].[sp_급여알림_자동생성]
    @거래처ID INT,
    @연도     INT,
    @월       INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @고객명 NVARCHAR(100), @Setting NVARCHAR(10), @Wonchun NVARCHAR(50), @TargetDay INT;
    DECLARE @MacroTitle NVARCHAR(200), @PayrollTitle NVARCHAR(200);
    DECLARE @Description NVARCHAR(200), @TargetDate DATE;

    -- 1. 거래처 정보 조회
    SELECT 
        @고객명 = 고객명, 
        @Setting = 발송설정, 
        @Wonchun = 원천세,
        @TargetDay = ISNULL(급여대장일, 10)
    FROM dbo.거래처 
    WHERE ID = @거래처ID;

    -- 2. 삭제(Cleanup) 로직: 원천세가 'O'가 아니거나 발송설정이 '사용안함'이면 모든 급여 알림 삭제
    IF (@Wonchun <> N'O' OR @Setting = N'사용안함')
    BEGIN
        DELETE FROM dbo.일정 
        WHERE 출처 = N'PAYROLL' 
          AND 참조ID = @거래처ID 
          AND 참조구분 IN (N'SEND_MACRO', N'SEND_PAYROLL');
        RETURN; -- 작업 종료
    END

    -- 3. 날짜 계산 (기존 로직 유지)
    BEGIN TRY
        SET @TargetDate = DATEFROMPARTS(@연도, @월, @TargetDay);
    END TRY
    BEGIN CATCH
        SET @TargetDate = EOMONTH(DATEFROMPARTS(@연도, @월, 1));
    END CATCH

    SET @Description = CAST(@연도 AS NVARCHAR(10)) + N'년 ' + CAST(@월 AS NVARCHAR(10)) + N'월분 발송 대기';

    -- 4. 개별 삭제 및 생성 로직
    
    -- [매크로] 설정이 아니면 기존 매크로 알림만 삭제, 맞으면 업서트
    IF (@Setting = N'매크로' OR @Setting = N'둘다')
    BEGIN
        SET @MacroTitle = N'[매크로] ' + @고객명 + N' – 명세서/대장';
        EXEC dbo.sp_일정_업서트_참조 
            @출처 = N'PAYROLL', @참조구분 = N'SEND_MACRO', @참조ID = @거래처ID, 
            @제목 = @MacroTitle, @설명 = @Description, @거래처ID = @거래처ID,
            @카테고리 = N'원천세', @신고기한 = @TargetDate;
    END
    ELSE
    BEGIN
        DELETE FROM dbo.일정 WHERE 출처 = N'PAYROLL' AND 참조구분 = N'SEND_MACRO' AND 참조ID = @거래처ID;
    END

    -- [급여앱] 설정이 아니면 기존 급여앱 알림만 삭제, 맞으면 업서트
    IF (@Setting = N'급여' OR @Setting = N'둘다')
    BEGIN
        SET @PayrollTitle = N'[급여앱] ' + @고객명 + N' – 명세서/대장';
        EXEC dbo.sp_일정_업서트_참조 
            @출처 = N'PAYROLL', @참조구분 = N'SEND_PAYROLL', @참조ID = @거래처ID,
            @제목 = @PayrollTitle, @설명 = @Description, @거래처ID = @거래처ID,
            @카테고리 = N'원천세', @신고기한 = @TargetDate;
    END
    ELSE
    BEGIN
        DELETE FROM dbo.일정 WHERE 출처 = N'PAYROLL' AND 참조구분 = N'SEND_PAYROLL' AND 참조ID = @거래처ID;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_일정_업서트_참조]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_일정_업서트_참조]
(
    @출처        NVARCHAR(20),
    @참조구분    NVARCHAR(30),
    @참조ID      INT,
    @제목        NVARCHAR(200) = NULL,
    @설명        NVARCHAR(200) = NULL,
    @카테고리    NVARCHAR(30)  = NULL,
    @거래처ID    INT = NULL,       -- ← 회사ID 대신 거래처ID 사용
    @납세자ID    INT = NULL,
    @사건구분    NVARCHAR(10) = NULL,
    @사건ID      INT = NULL,
    @시작일시    DATETIME2(0) = NULL,
    @종료일시    DATETIME2(0) = NULL,
    @종일        BIT = 1,
    @신고기한    DATE = NULL,
    @알림분전    INT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM dbo.일정 WHERE 출처=@출처 AND 참조구분=@참조구분 AND 참조ID=@참조ID)
    BEGIN
        UPDATE dbo.일정
           SET 제목      = COALESCE(@제목, 제목),
               설명      = COALESCE(@설명, 설명),
               카테고리  = COALESCE(@카테고리, 카테고리),
               거래처ID  = COALESCE(@거래처ID, 거래처ID),   -- ← 여기
               납세자ID  = COALESCE(@납세자ID, 납세자ID),
               사건구분  = COALESCE(@사건구분, 사건구분),
               사건ID    = COALESCE(@사건ID, 사건ID),
               시작일시  = COALESCE(@시작일시, 시작일시),
               종료일시  = COALESCE(@종료일시, 종료일시),
               종일      = COALESCE(@종일, 종일),
               신고기한  = COALESCE(@신고기한, 신고기한),
               알림분전  = COALESCE(@알림분전, 알림분전),
               수정일시  = SYSUTCDATETIME()
         WHERE 출처=@출처 AND 참조구분=@참조구분 AND 참조ID=@참조ID;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.일정
        (제목, 설명, 카테고리, 거래처ID, 납세자ID, 사건구분, 사건ID,
         시작일시, 종료일시, 종일, 신고기한, 알림분전, 출처, 참조구분, 참조ID, 중요, 상태)
        VALUES
        (@제목, @설명, @카테고리, @거래처ID, @납세자ID, @사건구분, @사건ID,
         @시작일시, @종료일시, @종일, @신고기한, @알림분전, @출처, @참조구분, @참조ID, 0, N'진행');
    END

    IF @알림분전 IS NOT NULL
    BEGIN
        DECLARE @일정ID INT =
            (SELECT TOP(1) 일정ID FROM dbo.일정 WHERE 출처=@출처 AND 참조구분=@참조구분 AND 참조ID=@참조ID);

        IF NOT EXISTS (SELECT 1 FROM dbo.일정알림 WHERE 일정ID=@일정ID AND 분전=@알림분전)
            INSERT INTO dbo.일정알림(일정ID, 분전) VALUES(@일정ID, @알림분전);

        EXEC dbo.sp_일정알림_다음알림_계산 @일정ID=@일정ID;
    END
END
GO
/****** Object:  StoredProcedure [dbo].[sp_일정알림_다음알림_계산]    Script Date: 2025-12-30 오전 11:45:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_일정알림_다음알림_계산]
    @일정ID INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @dt DATETIME2(0);

    SELECT @dt =
        COALESCE(
            시작일시,
            DATEADD(HOUR, 9, CAST(COALESCE(기준일, 신고기한) AS DATETIME2(0)))
        )
    FROM dbo.일정
    WHERE 일정ID=@일정ID;

    UPDATE a
       SET 다음알림일시 = DATEADD(MINUTE, -a.분전, @dt),
           수정일시     = SYSUTCDATETIME()
    FROM dbo.일정알림 a
    WHERE a.일정ID=@일정ID AND a.활성=1;
END
GO
USE [master]
GO
ALTER DATABASE [기본정보] SET  READ_WRITE 
GO
