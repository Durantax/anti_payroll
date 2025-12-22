-- ============================================================================
-- DB 마이그레이션: 주소정근로시간 (WeeklyHours) 및 개근주수 (WeekCount) 추가
-- ============================================================================
-- 작성일: 2024-12-22
-- 목적: 주 15시간 미만 주휴수당 판정 및 프리랜서 주휴수당 계산
-- ============================================================================

USE [payroll]
GO

-- 1. PayrollMonthlyInput 테이블에 WeeklyHours 필드 추가
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'[dbo].[PayrollMonthlyInput]') 
    AND name = 'WeeklyHours'
)
BEGIN
    ALTER TABLE [dbo].[PayrollMonthlyInput]
    ADD [WeeklyHours] DECIMAL(18,2) NOT NULL DEFAULT 40.0;
    
    PRINT 'WeeklyHours 필드 추가 완료'
END
ELSE
BEGIN
    PRINT 'WeeklyHours 필드 이미 존재'
END
GO

-- 2. PayrollMonthlyInput 테이블에 WeekCount 필드 추가
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID(N'[dbo].[PayrollMonthlyInput]') 
    AND name = 'WeekCount'
)
BEGIN
    ALTER TABLE [dbo].[PayrollMonthlyInput]
    ADD [WeekCount] INT NOT NULL DEFAULT 4;
    
    PRINT 'WeekCount 필드 추가 완료'
END
ELSE
BEGIN
    PRINT 'WeekCount 필드 이미 존재'
END
GO

-- 3. 기존 데이터 업데이트 (필요시)
-- 기존 레코드에 대해서도 기본값 40시간, 4주 설정
UPDATE [dbo].[PayrollMonthlyInput]
SET [WeeklyHours] = 40.0, [WeekCount] = 4
WHERE [WeeklyHours] IS NULL OR [WeekCount] IS NULL;
GO

-- 4. 확인 쿼리
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'PayrollMonthlyInput'
  AND COLUMN_NAME IN ('WeeklyHours', 'WeekCount')
ORDER BY ORDINAL_POSITION;
GO

PRINT '마이그레이션 완료!'
PRINT '- WeeklyHours: 주소정근로시간 (기본값 40.0시간)'
PRINT '- WeekCount: 개근주수 (기본값 4주)'
GO
