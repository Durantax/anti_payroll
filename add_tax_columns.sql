-- 📌 dbo.Employees 테이블에 세금 관련 컬럼 추가
-- 서버를 재시작하지 않고 직접 실행할 수 있는 SQL

USE [기본정보]
GO

-- 1. TaxDependents (부양가족수, 본인 포함)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Employees') AND name = 'TaxDependents')
BEGIN
    ALTER TABLE dbo.Employees ADD TaxDependents INT NOT NULL DEFAULT 1;
    PRINT '✅ TaxDependents 컬럼 추가 완료';
END
ELSE
    PRINT '⚠️ TaxDependents 컬럼이 이미 존재합니다';

-- 2. ChildrenCount (8-20세 자녀수)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Employees') AND name = 'ChildrenCount')
BEGIN
    ALTER TABLE dbo.Employees ADD ChildrenCount INT NOT NULL DEFAULT 0;
    PRINT '✅ ChildrenCount 컬럼 추가 완료';
END
ELSE
    PRINT '⚠️ ChildrenCount 컬럼이 이미 존재합니다';

-- 3. TaxFreeMeal (비과세 식대)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Employees') AND name = 'TaxFreeMeal')
BEGIN
    ALTER TABLE dbo.Employees ADD TaxFreeMeal DECIMAL(18,2) NOT NULL DEFAULT 0;
    PRINT '✅ TaxFreeMeal 컬럼 추가 완료';
END
ELSE
    PRINT '⚠️ TaxFreeMeal 컬럼이 이미 존재합니다';

-- 4. TaxFreeCarMaintenance (비과세 차량유지비)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Employees') AND name = 'TaxFreeCarMaintenance')
BEGIN
    ALTER TABLE dbo.Employees ADD TaxFreeCarMaintenance DECIMAL(18,2) NOT NULL DEFAULT 0;
    PRINT '✅ TaxFreeCarMaintenance 컬럼 추가 완료';
END
ELSE
    PRINT '⚠️ TaxFreeCarMaintenance 컬럼이 이미 존재합니다';

-- 5. OtherTaxFree (기타 비과세)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Employees') AND name = 'OtherTaxFree')
BEGIN
    ALTER TABLE dbo.Employees ADD OtherTaxFree DECIMAL(18,2) NOT NULL DEFAULT 0;
    PRINT '✅ OtherTaxFree 컬럼 추가 완료';
END
ELSE
    PRINT '⚠️ OtherTaxFree 컬럼이 이미 존재합니다';

-- 6. IncomeTaxRate (소득세율 배율: 80, 100, 120)
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Employees') AND name = 'IncomeTaxRate')
BEGIN
    ALTER TABLE dbo.Employees ADD IncomeTaxRate INT NOT NULL DEFAULT 100;
    PRINT '✅ IncomeTaxRate 컬럼 추가 완료';
END
ELSE
    PRINT '⚠️ IncomeTaxRate 컬럼이 이미 존재합니다';

PRINT '🎉 모든 세금 관련 컬럼 추가 작업 완료!';
GO
