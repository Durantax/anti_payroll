-- ============================================================================
-- 간단 버전: WeeklyHours, WeekCount 필드 추가
-- ============================================================================
-- 실행 방법:
-- 1. SQL Server Management Studio (SSMS)에서 실행
-- 2. 또는 sqlcmd: sqlcmd -S 서버명 -d payroll -i add_weekly_hours_SIMPLE.sql
-- ============================================================================

USE [payroll];
GO

-- WeeklyHours 필드 추가 (주소정근로시간)
ALTER TABLE [dbo].[PayrollMonthlyInput]
ADD [WeeklyHours] DECIMAL(18,2) NOT NULL DEFAULT 40.0;
GO

-- WeekCount 필드 추가 (개근주수)
ALTER TABLE [dbo].[PayrollMonthlyInput]
ADD [WeekCount] INT NOT NULL DEFAULT 4;
GO

-- 확인
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PayrollMonthlyInput'
  AND COLUMN_NAME IN ('WeeklyHours', 'WeekCount');
GO

PRINT '완료!';
GO
