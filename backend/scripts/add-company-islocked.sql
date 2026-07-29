:setvar DatabaseName "TTSmartMobile_Dev"

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @DatabaseName sysname = N'$(DatabaseName)';

IF @DatabaseName <> N'TTSmartMobile_Dev'
BEGIN
    THROW 51000, N'Script chỉ được phép chạy trên TTSmartMobile_Dev.', 1;
END;

IF DB_ID(@DatabaseName) IS NULL
BEGIN
    THROW 51001, N'Không tìm thấy database TTSmartMobile_Dev.', 1;
END;

DECLARE @Sql nvarchar(max) = N'
USE ' + QUOTENAME(@DatabaseName) + N';

IF OBJECT_ID(N''dbo.Company'', N''U'') IS NULL
BEGIN
    THROW 51002, N''Không tìm thấy bảng dbo.Company.'', 1;
END;

IF COL_LENGTH(N''dbo.Company'', N''IsLocked'') IS NULL
BEGIN
    ALTER TABLE dbo.Company
        ADD IsLocked bit NOT NULL
            CONSTRAINT DF_Company_IsLocked DEFAULT (0) WITH VALUES;
END;

IF EXISTS
(
    SELECT 1
    FROM sys.columns AS columns
    JOIN sys.types AS types
        ON columns.user_type_id = types.user_type_id
    WHERE columns.object_id = OBJECT_ID(N''dbo.Company'')
      AND columns.name = N''IsLocked''
      AND (types.name <> N''bit'' OR columns.is_nullable <> 0)
)
BEGIN
    THROW 51003, N''Company.IsLocked phải là bit NOT NULL.'', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.default_constraints AS defaults
    JOIN sys.columns AS columns
        ON defaults.parent_object_id = columns.object_id
       AND defaults.parent_column_id = columns.column_id
    WHERE defaults.parent_object_id = OBJECT_ID(N''dbo.Company'')
      AND columns.name = N''IsLocked''
)
BEGIN
    ALTER TABLE dbo.Company
        ADD CONSTRAINT DF_Company_IsLocked DEFAULT (0) FOR IsLocked;
END;

SELECT
    DB_NAME() AS DatabaseName,
    columns.name AS ColumnName,
    types.name AS DataType,
    columns.is_nullable AS IsNullable,
    defaults.definition AS DefaultDefinition
FROM sys.columns AS columns
JOIN sys.types AS types
    ON columns.user_type_id = types.user_type_id
LEFT JOIN sys.default_constraints AS defaults
    ON columns.default_object_id = defaults.object_id
WHERE columns.object_id = OBJECT_ID(N''dbo.Company'')
  AND columns.name = N''IsLocked'';
';

EXEC sys.sp_executesql @Sql;
