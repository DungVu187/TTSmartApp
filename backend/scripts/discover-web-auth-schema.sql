/*
    Read-only discovery for the website authentication and authorization schema.
    DatabaseName must be supplied by sqlcmd with -v.
    Example: sqlcmd ... -v DatabaseName="TTSmartMobile_Dev"
    The script never returns password values or user personal information.
*/

USE [$(DatabaseName)];
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @Tables TABLE (TableName sysname PRIMARY KEY);
INSERT INTO @Tables (TableName)
VALUES (N'User'), (N'Role'), (N'UserRole'), (N'Function'), (N'FunctionRole');

SELECT
    N'DATABASE' AS ResultSet,
    DB_NAME() AS DatabaseName,
    databaseItem.state_desc AS State,
    databaseItem.compatibility_level AS CompatibilityLevel,
    databaseItem.collation_name AS CollationName,
    databaseItem.is_read_only AS IsReadOnly
FROM sys.databases AS databaseItem
WHERE databaseItem.database_id = DB_ID();

SELECT
    N'TABLES' AS ResultSet,
    tableName.TableName,
    CASE WHEN tableItem.object_id IS NULL THEN 0 ELSE 1 END AS ExistsInDbo
FROM @Tables AS tableName
LEFT JOIN sys.tables AS tableItem
    ON tableItem.schema_id = SCHEMA_ID(N'dbo')
   AND tableItem.name = tableName.TableName
ORDER BY tableName.TableName;

SELECT
    N'COLUMNS' AS ResultSet,
    tableItem.name AS TableName,
    columnItem.column_id AS ColumnOrder,
    columnItem.name AS ColumnName,
    typeItem.name AS SqlType,
    columnItem.max_length AS MaxLength,
    columnItem.precision AS PrecisionValue,
    columnItem.scale AS ScaleValue,
    columnItem.is_nullable AS IsNullable,
    columnItem.is_identity AS IsIdentity,
    columnItem.is_computed AS IsComputed,
    defaultItem.definition AS DefaultDefinition,
    computedItem.definition AS ComputedDefinition
FROM sys.tables AS tableItem
JOIN @Tables AS selectedTable ON selectedTable.TableName = tableItem.name
JOIN sys.columns AS columnItem ON columnItem.object_id = tableItem.object_id
JOIN sys.types AS typeItem ON typeItem.user_type_id = columnItem.user_type_id
LEFT JOIN sys.default_constraints AS defaultItem
    ON defaultItem.parent_object_id = columnItem.object_id
   AND defaultItem.parent_column_id = columnItem.column_id
LEFT JOIN sys.computed_columns AS computedItem
    ON computedItem.object_id = columnItem.object_id
   AND computedItem.column_id = columnItem.column_id
WHERE tableItem.schema_id = SCHEMA_ID(N'dbo')
ORDER BY tableItem.name, columnItem.column_id;

SELECT
    N'INDEXES' AS ResultSet,
    tableItem.name AS TableName,
    indexItem.name AS IndexName,
    indexItem.is_primary_key AS IsPrimaryKey,
    indexItem.is_unique AS IsUnique,
    indexItem.type_desc AS IndexType,
    indexColumn.key_ordinal AS KeyOrdinal,
    indexColumn.is_included_column AS IsIncluded,
    columnItem.name AS ColumnName,
    indexItem.filter_definition AS FilterDefinition
FROM sys.tables AS tableItem
JOIN @Tables AS selectedTable ON selectedTable.TableName = tableItem.name
JOIN sys.indexes AS indexItem ON indexItem.object_id = tableItem.object_id
JOIN sys.index_columns AS indexColumn
    ON indexColumn.object_id = indexItem.object_id
   AND indexColumn.index_id = indexItem.index_id
JOIN sys.columns AS columnItem
    ON columnItem.object_id = indexColumn.object_id
   AND columnItem.column_id = indexColumn.column_id
WHERE tableItem.schema_id = SCHEMA_ID(N'dbo')
  AND indexItem.is_hypothetical = 0
ORDER BY tableItem.name, indexItem.name, indexColumn.key_ordinal, indexColumn.index_column_id;

SELECT
    N'FOREIGN_KEYS' AS ResultSet,
    foreignKey.name AS ForeignKeyName,
    parentTable.name AS ParentTable,
    parentColumn.name AS ParentColumn,
    referencedTable.name AS ReferencedTable,
    referencedColumn.name AS ReferencedColumn,
    foreignKey.delete_referential_action_desc AS DeleteAction,
    foreignKey.update_referential_action_desc AS UpdateAction,
    foreignKey.is_disabled AS IsDisabled,
    foreignKey.is_not_trusted AS IsNotTrusted
FROM sys.foreign_keys AS foreignKey
JOIN sys.foreign_key_columns AS foreignKeyColumn
    ON foreignKeyColumn.constraint_object_id = foreignKey.object_id
JOIN sys.tables AS parentTable ON parentTable.object_id = foreignKey.parent_object_id
JOIN sys.columns AS parentColumn
    ON parentColumn.object_id = foreignKey.parent_object_id
   AND parentColumn.column_id = foreignKeyColumn.parent_column_id
JOIN sys.tables AS referencedTable ON referencedTable.object_id = foreignKey.referenced_object_id
JOIN sys.columns AS referencedColumn
    ON referencedColumn.object_id = foreignKey.referenced_object_id
   AND referencedColumn.column_id = foreignKeyColumn.referenced_column_id
WHERE parentTable.name IN (SELECT TableName FROM @Tables)
   OR referencedTable.name IN (SELECT TableName FROM @Tables)
ORDER BY parentTable.name, foreignKey.name, foreignKeyColumn.constraint_column_id;

SELECT
    N'CHECK_CONSTRAINTS' AS ResultSet,
    tableItem.name AS TableName,
    checkItem.name AS ConstraintName,
    checkItem.definition AS Definition,
    checkItem.is_disabled AS IsDisabled,
    checkItem.is_not_trusted AS IsNotTrusted
FROM sys.check_constraints AS checkItem
JOIN sys.tables AS tableItem ON tableItem.object_id = checkItem.parent_object_id
WHERE tableItem.name IN (SELECT TableName FROM @Tables)
ORDER BY tableItem.name, checkItem.name;

SELECT
    N'TRIGGERS' AS ResultSet,
    tableItem.name AS TableName,
    triggerItem.name AS TriggerName,
    triggerItem.is_disabled AS IsDisabled,
    moduleItem.definition AS Definition
FROM sys.triggers AS triggerItem
JOIN sys.tables AS tableItem ON tableItem.object_id = triggerItem.parent_id
LEFT JOIN sys.sql_modules AS moduleItem ON moduleItem.object_id = triggerItem.object_id
WHERE tableItem.name IN (SELECT TableName FROM @Tables)
ORDER BY tableItem.name, triggerItem.name;

SELECT DISTINCT
    N'DEPENDENCIES' AS ResultSet,
    referencedTable.name AS ReferencedTable,
    OBJECT_SCHEMA_NAME(dependency.referencing_id) AS ReferencingSchema,
    OBJECT_NAME(dependency.referencing_id) AS ReferencingObject,
    objectItem.type_desc AS ObjectType
FROM sys.sql_expression_dependencies AS dependency
JOIN sys.tables AS referencedTable ON referencedTable.object_id = dependency.referenced_id
LEFT JOIN sys.objects AS objectItem ON objectItem.object_id = dependency.referencing_id
WHERE referencedTable.name IN (SELECT TableName FROM @Tables)
ORDER BY referencedTable.name, ReferencingSchema, ReferencingObject;

SELECT
    N'ROW_COUNTS' AS ResultSet,
    tableItem.name AS TableName,
    SUM(partitionItem.rows) AS [RowCount]
FROM sys.tables AS tableItem
JOIN @Tables AS selectedTable ON selectedTable.TableName = tableItem.name
JOIN sys.indexes AS indexItem
    ON indexItem.object_id = tableItem.object_id
   AND indexItem.index_id IN (0, 1)
JOIN sys.partitions AS partitionItem
    ON partitionItem.object_id = indexItem.object_id
   AND partitionItem.index_id = indexItem.index_id
WHERE tableItem.schema_id = SCHEMA_ID(N'dbo')
GROUP BY tableItem.name
ORDER BY tableItem.name;

IF OBJECT_ID(N'dbo.User', N'U') IS NOT NULL
BEGIN
    SELECT
        N'USER_PROFILE' AS ResultSet,
        CONVERT(nvarchar(200), [Status]) AS StatusValue,
        LEN([Password]) AS PasswordCharacterLength,
        DATALENGTH([Password]) AS PasswordByteLength,
        CASE
            WHEN LEN([Password]) = 32 AND [Password] NOT LIKE N'%[^0-9A-Fa-f]%'
                THEN N'HEX_32_CANDIDATE'
            ELSE N'OTHER'
        END AS PasswordShape,
        COUNT_BIG(*) AS UserCount
    FROM dbo.[User]
    GROUP BY
        CONVERT(nvarchar(200), [Status]),
        LEN([Password]),
        DATALENGTH([Password]),
        CASE
            WHEN LEN([Password]) = 32 AND [Password] NOT LIKE N'%[^0-9A-Fa-f]%'
                THEN N'HEX_32_CANDIDATE'
            ELSE N'OTHER'
        END
    ORDER BY StatusValue, PasswordCharacterLength, PasswordByteLength;

    SELECT
        N'USER_QUALITY' AS ResultSet,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM([UserName])), N'') IS NULL THEN 1 ELSE 0 END) AS MissingUserNameCount,
        SUM(CASE WHEN NULLIF(LTRIM(RTRIM([Password])), N'') IS NULL THEN 1 ELSE 0 END) AS MissingPasswordCount,
        (
            SELECT COUNT_BIG(*)
            FROM
            (
                SELECT [UserName]
                FROM dbo.[User]
                GROUP BY [UserName]
                HAVING COUNT_BIG(*) > 1
            ) AS duplicateUserName
        ) AS DuplicateUserNameGroupCount
    FROM dbo.[User];
END;

IF OBJECT_ID(N'dbo.Role', N'U') IS NOT NULL
BEGIN
    SELECT
        N'ROLE_DATA' AS ResultSet,
        [RoleId], [Code], [Name], [LevelRole], [Status]
    FROM dbo.[Role]
    ORDER BY [LevelRole], [Code], [Name], [RoleId];
END;

IF OBJECT_ID(N'dbo.Function', N'U') IS NOT NULL
BEGIN
    SELECT
        N'FUNCTION_DATA' AS ResultSet,
        [FunctionId], [FunctionParentId], [Code], [Name], [Url], [Location], [Status]
    FROM dbo.[Function]
    ORDER BY [FunctionParentId], [Location], [Code], [Name], [FunctionId];
END;

IF OBJECT_ID(N'dbo.FunctionRole', N'U') IS NOT NULL
BEGIN
    SELECT
        N'FUNCTION_ROLE_PROFILE' AS ResultSet,
        CONVERT(nvarchar(200), [Type]) AS TypeValue,
        CONVERT(nvarchar(200), [Status]) AS StatusValue,
        CONVERT(nvarchar(4000), [ActiveKey]) AS ActiveKeyValue,
        COUNT_BIG(*) AS AssignmentCount
    FROM dbo.[FunctionRole]
    GROUP BY
        CONVERT(nvarchar(200), [Type]),
        CONVERT(nvarchar(200), [Status]),
        CONVERT(nvarchar(4000), [ActiveKey])
    ORDER BY TypeValue, StatusValue, ActiveKeyValue;

    SELECT TOP (500)
        N'FUNCTION_ROLE_DATA' AS ResultSet,
        [FunctionRoleId], [TargetId], [FunctionId], [ActiveKey], [Type], [UserId], [Status]
    FROM dbo.[FunctionRole]
    ORDER BY [TargetId], [FunctionId], [FunctionRoleId];
END;

IF OBJECT_ID(N'dbo.UserRole', N'U') IS NOT NULL
BEGIN
    SELECT TOP (500)
        N'USER_ROLE_DATA' AS ResultSet,
        [UserRoleId], [UserId], [RoleId], [Status]
    FROM dbo.[UserRole]
    ORDER BY [UserId], [RoleId], [UserRoleId];
END;
