-- 초기 데이터 삽입 스크립트
-- AppSettings와 SmtpConfig 테이블에 기본값 삽입

USE [기본정보];
GO

-- AppSettings 초기 데이터
IF NOT EXISTS (SELECT 1 FROM dbo.AppSettings WHERE Id = 1)
BEGIN
    INSERT INTO dbo.AppSettings (Id, ServerUrl, ApiKey, UpdatedAt)
    VALUES (1, N'http://25.2.89.129:8000', N'', SYSUTCDATETIME());
    PRINT 'AppSettings 초기 데이터 삽입 완료';
END
ELSE
BEGIN
    PRINT 'AppSettings 데이터가 이미 존재합니다.';
END
GO

-- SmtpConfig 초기 데이터 (빈 설정)
IF NOT EXISTS (SELECT 1 FROM dbo.SmtpConfig WHERE Id = 1)
BEGIN
    INSERT INTO dbo.SmtpConfig (Id, Host, Port, Username, Password, UseSSL, UpdatedAt)
    VALUES (1, N'smtp.gmail.com', 587, N'', N'', 1, SYSUTCDATETIME());
    PRINT 'SmtpConfig 초기 데이터 삽입 완료';
END
ELSE
BEGIN
    PRINT 'SmtpConfig 데이터가 이미 존재합니다.';
END
GO

-- 데이터 확인
SELECT 'AppSettings' AS TableName, * FROM dbo.AppSettings WHERE Id = 1;
SELECT 'SmtpConfig' AS TableName, * FROM dbo.SmtpConfig WHERE Id = 1;
GO
