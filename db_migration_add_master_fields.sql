-- Migration Script: Add Required Fields
-- Modifies PayrollMonthlyInput to support dynamic masters
-- Date: 2026-01-01

USE [기본정보]
GO

PRINT '========================================';
PRINT 'DB 마이그레이션 시작';
PRINT '========================================';

--  1. AllowanceMasters에 IsTaxFree가 이미 있는지 확인 (이미 있음!)
IF COL_LENGTH('dbo.AllowanceMasters', 'IsTaxFree') IS NOT NULL
BEGIN
    PRINT '✓ AllowanceMasters.IsTaxFree 이미 존재';
END
ELSE
BEGIN
    ALTER TABLE dbo.AllowanceMasters ADD IsTaxFree BIT NOT NULL DEFAULT 0;
    PRINT '+ AllowanceMasters.IsTaxFree 추가됨';
END

-- 2. AllowanceMasters에 DefaultAmount가 이미 있는지 확인 (이미 있음!)
IF COL_LENGTH('dbo.AllowanceMasters', 'DefaultAmount') IS NOT NULL
BEGIN
    PRINT '✓ AllowanceMasters.DefaultAmount 이미 존재';
END
ELSE
BEGIN
    ALTER TABLE dbo.AllowanceMasters ADD DefaultAmount DECIMAL(18,2) NULL;
    PRINT '+ AllowanceMasters.DefaultAmount 추가됨';
END

-- 3. DeductionMasters에 DefaultAmount 확인 (이미 있음!)
IF COL_LENGTH('dbo.DeductionMasters', 'DefaultAmount') IS NOT NULL
BEGIN
    PRINT '✓ DeductionMasters.DefaultAmount 이미 존재';
END
ELSE
BEGIN
    ALTER TABLE dbo.DeductionMasters ADD DefaultAmount DECIMAL(18,2) NULL;
    PRINT '+ DeductionMasters.DefaultAmount 추가됨';
END

PRINT '';
PRINT '========================================';
PRINT 'PayrollMonthlyInput 수정 시작';
PRINT '========================================';

-- 4. PayrollMonthlyInput에 AdditionalPay1, 2, 3 추가
IF COL_LENGTH('dbo.PayrollMonthlyInput', 'AdditionalPay1') IS NULL
BEGIN
    ALTER TABLE dbo.PayrollMonthlyInput 
    ADD AdditionalPay1 INT NOT NULL DEFAULT 0,
        AdditionalPay1Name NVARCHAR(100) NULL,
        AdditionalPay1IsTaxFree BIT NOT NULL DEFAULT 0;
    PRINT '+ AdditionalPay1 필드 추가됨';
END
ELSE
BEGIN
    PRINT '✓ AdditionalPay1 필드 이미 존재';
END

IF COL_LENGTH('dbo.PayrollMonthlyInput', 'AdditionalPay2') IS NULL
BEGIN
    ALTER TABLE dbo.PayrollMonthlyInput 
    ADD AdditionalPay2 INT NOT NULL DEFAULT 0,
        AdditionalPay2Name NVARCHAR(100) NULL,
        AdditionalPay2IsTaxFree BIT NOT NULL DEFAULT 0;
    PRINT '+ AdditionalPay2 필드 추가됨';
END
ELSE
BEGIN
    PRINT '✓ AdditionalPay2 필드 이미 존재';
END

IF COL_LENGTH('dbo.PayrollMonthlyInput', 'AdditionalPay3') IS NULL
BEGIN
    ALTER TABLE dbo.PayrollMonthlyInput 
    ADD AdditionalPay3 INT NOT NULL DEFAULT 0,
        AdditionalPay3Name NVARCHAR(100) NULL,
        AdditionalPay3IsTaxFree BIT NOT NULL DEFAULT 0;
    PRINT '+ AdditionalPay3 필드 추가됨';
END
ELSE
BEGIN
    PRINT '✓ AdditionalPay3 필드 이미 존재';
END

-- 5. PayrollMonthlyInput에 AdditionalDeduct1, 2, 3 추가
IF COL_LENGTH('dbo.PayrollMonthlyInput', 'AdditionalDeduct1') IS NULL
BEGIN
    ALTER TABLE dbo.PayrollMonthlyInput 
    ADD AdditionalDeduct1 INT NOT NULL DEFAULT 0,
        AdditionalDeduct1Name NVARCHAR(100) NULL;
    PRINT '+ AdditionalDeduct1 필드 추가됨';
END
ELSE
BEGIN
    PRINT '✓ AdditionalDeduct1 필드 이미 존재';
END

IF COL_LENGTH('dbo.PayrollMonthlyInput', 'AdditionalDeduct2') IS NULL
BEGIN
    ALTER TABLE dbo.PayrollMonthlyInput 
    ADD AdditionalDeduct2 INT NOT NULL DEFAULT 0,
        AdditionalDeduct2Name NVARCHAR(100) NULL;
    PRINT '+ AdditionalDeduct2 필드 추가됨';
END
ELSE
BEGIN
    PRINT '✓ AdditionalDeduct2 필드 이미 존재';
END

IF COL_LENGTH('dbo.PayrollMonthlyInput', 'AdditionalDeduct3') IS NULL
BEGIN
    ALTER TABLE dbo.PayrollMonthlyInput 
    ADD AdditionalDeduct3 INT NOT NULL DEFAULT 0,
        AdditionalDeduct3Name NVARCHAR(100) NULL;
    PRINT '+ AdditionalDeduct3 필드 추가됨';
END
ELSE
BEGIN
    PRINT '✓ AdditionalDeduct3 필드 이미 존재';
END

PRINT '';
PRINT '========================================';
PRINT '마이그레이션 완료!';
PRINT '========================================';
PRINT '';
PRINT '사용 중인 테이블:';
PRINT '  - AllowanceMasters (IsTaxFree, DefaultAmount 있음)';
PRINT '  - DeductionMasters (DefaultAmount 있음)';
PRINT '  - PayrollMonthlyInput (AdditionalPay1/2/3, AdditionalDeduct1/2/3 추가됨)';
GO
